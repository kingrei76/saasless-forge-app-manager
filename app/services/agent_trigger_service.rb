class AgentTriggerService
  class << self
    # Called by AgentTriggerProcessorJob every minute
    def process_scheduled_triggers
      triggers = AgentTrigger.enabled.by_type("schedule")
        .joins(:agent).where(agents: { status: "active" })

      fired = 0
      triggers.find_each do |trigger|
        next if trigger.within_cooldown?
        next unless cron_matches_now?(trigger.cron_expression)

        begin
          trigger.fire!
          fired += 1
        rescue => e
          create_trigger_alert(trigger, "Schedule trigger failed: #{e.message}")
        end
      end
      fired
    end

    # Called by AgentTriggerProcessorJob every minute
    def process_data_triggers
      triggers = AgentTrigger.enabled.by_type("data")
        .joins(:agent).where(agents: { status: "active" })
        .includes(:tool_definition)

      fired = 0
      triggers.find_each do |trigger|
        next unless trigger.should_check_now?

        begin
          trigger.update!(last_checked_at: Time.current)
          data = poll_tool(trigger)
          next unless data

          if trigger.evaluate_condition(data)
            trigger.fire!(data)
            fired += 1
          end
        rescue => e
          create_trigger_alert(trigger, "Data trigger check failed: #{e.message}")
        end
      end
      fired
    end

    # Fire event triggers from anywhere in the app
    def fire_event(event_name, data = {})
      triggers = AgentTrigger.enabled.by_type("event")
        .joins(:agent).where(agents: { status: "active" })
        .where(event_name: event_name)

      fired = 0
      triggers.find_each do |trigger|
        next if trigger.within_cooldown?
        next unless trigger.evaluate_condition(data)

        begin
          trigger.fire!(data)
          fired += 1
        rescue => e
          create_trigger_alert(trigger, "Event trigger failed: #{e.message}")
        end
      end
      fired
    end

    # Called from execution_done callback
    def fire_dependency(agent, execution)
      return 0 unless execution.status == "completed"

      triggers = AgentTrigger.enabled.by_type("dependency")
        .joins(:agent).where(agents: { status: "active" })
        .where(depends_on_agent_id: agent.id)

      fired = 0
      triggers.find_each do |trigger|
        next if trigger.within_cooldown?

        output = execution.output_data || {}
        next unless trigger.evaluate_condition(output)

        begin
          trigger.fire!(output)
          fired += 1
        rescue => e
          create_trigger_alert(trigger, "Dependency trigger failed: #{e.message}")
        end
      end
      fired
    end

    # Called from webhook controller
    def fire_webhook(webhook_token, payload)
      trigger = AgentTrigger.enabled.find_by(webhook_token: webhook_token, trigger_type: "webhook")
      return nil unless trigger
      return nil unless trigger.agent.status == "active"
      return nil if trigger.within_cooldown?

      data = payload.is_a?(String) ? (JSON.parse(payload) rescue {}) : payload
      return nil unless trigger.evaluate_condition(data)

      trigger.fire!(data)
    end

    # Core condition evaluator
    def evaluate_conditions(condition_json, data)
      return true if condition_json.blank?

      condition = condition_json.is_a?(String) ? JSON.parse(condition_json) : condition_json
      return true if condition.empty?

      rules = condition["rules"]
      return true if rules.blank?

      match_mode = condition["match"] || "all"
      results = rules.map { |rule| evaluate_rule(rule, data) }

      if match_mode == "any"
        results.any?
      else
        results.all?
      end
    end

    private

    def evaluate_rule(rule, data)
      field = rule["field"]
      operator = rule["operator"]
      expected = rule["value"]

      actual = extract_field(data, field)

      case operator
      when "equals"
        actual.to_s == expected.to_s
      when "not_equals"
        actual.to_s != expected.to_s
      when "greater_than"
        actual.to_f > expected.to_f
      when "less_than"
        actual.to_f < expected.to_f
      when "greater_than_or_equal"
        actual.to_f >= expected.to_f
      when "less_than_or_equal"
        actual.to_f <= expected.to_f
      when "contains"
        actual.to_s.include?(expected.to_s)
      when "not_contains"
        !actual.to_s.include?(expected.to_s)
      when "starts_with"
        actual.to_s.start_with?(expected.to_s)
      when "ends_with"
        actual.to_s.end_with?(expected.to_s)
      when "exists"
        !actual.nil?
      when "not_exists"
        actual.nil?
      when "in"
        Array(expected).map(&:to_s).include?(actual.to_s)
      when "not_in"
        !Array(expected).map(&:to_s).include?(actual.to_s)
      when "matches"
        actual.to_s.match?(Regexp.new(expected.to_s))
      else
        false
      end
    rescue => e
      Rails.logger.warn("AgentTriggerService: Rule evaluation error: #{e.message}")
      false
    end

    # Extract value from nested hash using dot notation with array indexing
    # e.g. "data.items[0].name" extracts data["items"][0]["name"]
    def extract_field(data, field_path)
      return nil if data.nil? || field_path.blank?

      data = data.with_indifferent_access if data.is_a?(Hash)
      parts = field_path.split(".")

      current = data
      parts.each do |part|
        return nil if current.nil?

        if part =~ /\A(.+)\[(\d+)\]\z/
          key = $1
          index = $2.to_i
          current = current.is_a?(Hash) ? current[key] : nil
          current = current.is_a?(Array) ? current[index] : nil
        else
          current = current.is_a?(Hash) ? current[part] : nil
        end
      end

      current
    end

    def cron_matches_now?(cron_expr)
      return false if cron_expr.blank?

      now = Time.current
      parts = cron_expr.strip.split(/\s+/)
      return false unless parts.length == 5

      minute, hour, day, month, dow = parts

      matches_field?(minute, now.min) &&
        matches_field?(hour, now.hour) &&
        matches_field?(day, now.day) &&
        matches_field?(month, now.month) &&
        matches_dow?(dow, now.wday)
    end

    def matches_field?(pattern, value)
      return true if pattern == "*"

      if pattern.include?("/")
        # Step values: */5, */15, etc.
        base, step = pattern.split("/")
        step = step.to_i
        return false if step.zero?
        if base == "*"
          return (value % step).zero?
        else
          return value >= base.to_i && ((value - base.to_i) % step).zero?
        end
      end

      if pattern.include?(",")
        return pattern.split(",").map(&:strip).map(&:to_i).include?(value)
      end

      if pattern.include?("-")
        low, high = pattern.split("-").map(&:to_i)
        return value >= low && value <= high
      end

      pattern.to_i == value
    end

    def matches_dow?(pattern, wday)
      return true if pattern == "*"
      # Convert Sunday from 0 to 7 for compatibility, but keep both
      matches_field?(pattern, wday) || (wday == 0 && matches_field?(pattern, 7))
    end

    def poll_tool(trigger)
      tool = trigger.tool_definition
      return nil unless tool

      # Build a simple HTTP request to the tool's API endpoint
      # Tools store their endpoint info in input_schema or metadata
      # For now, use the LangGraph client to invoke the tool
      client = LanggraphClient.new
      response = client.health_check # Placeholder — actual tool polling depends on tool API setup
      # TODO: Implement actual tool API polling when tool endpoint format is finalized
      Rails.logger.info("AgentTriggerService: Polled tool #{tool.slug} for trigger ##{trigger.id}")
      response
    rescue => e
      Rails.logger.error("AgentTriggerService: Failed to poll tool #{tool&.slug}: #{e.message}")
      nil
    end

    def create_trigger_alert(trigger, message)
      AgentAlert.create(
        agent: trigger.agent,
        alert_type: "error",
        severity: "warning",
        title: "Trigger ##{trigger.id} error",
        description: message
      )
      Rails.logger.error("AgentTriggerService: #{message}")
    end
  end
end
