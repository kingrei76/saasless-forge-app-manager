class ToolRegistryService
  def self.sync!
    new.sync!
  end

  def self.discover_model_tools
    new.discover_model_tools
  end

  def self.detect_changes
    new.detect_changes
  end

  def self.full_sync!
    new.full_sync!
  end

  # Sync hand-coded AgentTools:: classes into ToolDefinition records
  def sync!
    discovered = discover_tools
    synced = 0
    skipped = 0

    discovered.each do |tool_class|
      meta = tool_class.tool_metadata
      slug = meta[:name].parameterize

      tool = ToolDefinition.find_or_initialize_by(slug: slug)
      was_new = tool.new_record?

      tool.assign_attributes(
        name: meta[:name],
        handler_class: tool_class.name,
        category: meta[:category],
        input_schema: meta[:input_schema],
        output_schema: meta[:output_schema],
        risk_level: meta[:risk_level]
      )

      # Only update description if it's a new tool (preserve manual edits)
      tool.description = meta[:description] if was_new

      if tool.changed?
        tool.version += 1 unless was_new
        tool.save!
        synced += 1
        Rails.logger.info("ToolRegistry: #{was_new ? 'Created' : 'Updated'} #{tool.name}")
      else
        skipped += 1
      end
    end

    { synced: synced, skipped: skipped, total: discovered.count }
  end

  # Auto-discover models and create generic CRUD tool definitions for models
  # that have API controllers but no hand-coded AgentTools:: class.
  def discover_model_tools
    models = ModelIntrospector.discover[:models] || []
    api_routes = RouteIntrospector.api_endpoints
    hand_coded = discover_tools.map { |t| t.tool_metadata[:name].parameterize }

    created = 0
    skipped = 0

    models.each do |model_info|
      model_name = model_info[:name]
      next unless model_info[:table_exists]

      # Check if this model has any API routes (controller named after the model)
      controller_name = "api/#{model_name.underscore.pluralize}"
      has_api = api_routes.any? { |r| r[:controller] == controller_name }

      # Also accept models with admin controllers
      admin_controller = "admin/#{model_name.underscore.pluralize}"
      has_admin = api_routes.empty? ? false : true # We always create for trackable models

      # Skip if a hand-coded tool already exists for this model
      slug = "list-#{model_name.underscore.dasherize.pluralize}"
      next if hand_coded.include?(slug)
      next if ToolDefinition.exists?(slug: slug, handler_class: "auto")

      # Only auto-generate for models that have meaningful columns
      columns = model_info[:columns] || []
      next if columns.size < 3 # Skip join tables and trivial models

      tool = ToolDefinition.find_or_initialize_by(slug: slug)
      if tool.new_record?
        tool.assign_attributes(
          name: "List #{model_name.titleize.pluralize}",
          description: "Auto-discovered: Query #{model_name} records with filtering. #{columns.size} columns available.",
          handler_class: "auto",
          category: "database",
          risk_level: "low",
          input_schema: build_auto_input_schema(model_info),
          output_schema: { type: "object", properties: { records: { type: "array" }, total_count: { type: "integer" } } }
        )
        tool.save!
        created += 1
        Rails.logger.info("ToolRegistry: Auto-discovered #{tool.name}")
      else
        skipped += 1
      end
    end

    { created: created, skipped: skipped }
  end

  # Compare current schema fingerprint against the last stored one.
  # Returns a diff describing what changed.
  def detect_changes
    current_fingerprint = compute_fingerprint
    stored_fingerprint = Setting["tool_discovery_fingerprint"]

    if stored_fingerprint.nil?
      # First run: store fingerprint and report as baseline
      Setting["tool_discovery_fingerprint"] = current_fingerprint.to_json
      return { status: "baseline", message: "Initial fingerprint stored", changes: [] }
    end

    begin
      old = JSON.parse(stored_fingerprint)
    rescue
      old = {}
    end

    changes = []

    # Detect new models
    new_models = current_fingerprint[:models].keys - (old["models"]&.keys || [])
    changes << { type: "new_models", items: new_models } if new_models.any?

    # Detect removed models
    removed_models = (old["models"]&.keys || []) - current_fingerprint[:models].keys
    changes << { type: "removed_models", items: removed_models } if removed_models.any?

    # Detect column changes per model
    current_fingerprint[:models].each do |model_name, columns|
      old_columns = old.dig("models", model_name) || []
      new_columns = columns - old_columns
      removed_columns = old_columns - columns
      changes << { type: "new_columns", model: model_name, items: new_columns } if new_columns.any?
      changes << { type: "removed_columns", model: model_name, items: removed_columns } if removed_columns.any?
    end

    # Detect new API routes
    new_routes = current_fingerprint[:api_routes] - (old["api_routes"] || [])
    changes << { type: "new_api_routes", items: new_routes } if new_routes.any?

    # Update stored fingerprint
    Setting["tool_discovery_fingerprint"] = current_fingerprint.to_json

    { status: changes.any? ? "changed" : "unchanged", changes: changes }
  end

  # Run full sync: hand-coded tools + model discovery + change detection
  def full_sync!
    sync_result = sync!
    discovery_result = discover_model_tools
    change_result = detect_changes

    {
      sync: sync_result,
      discovery: discovery_result,
      changes: change_result
    }
  end

  private

  def discover_tools
    # Eager-load all tool classes under AgentTools namespace
    tools_dir = Rails.root.join("app", "services", "agent_tools")
    Dir[tools_dir.join("**", "*.rb")].each { |f| require_dependency(f) }

    AgentTools::Base.descendants.select { |klass| klass != AgentTools::Base }
  rescue => e
    Rails.logger.error("ToolRegistry: Discovery failed - #{e.message}")
    []
  end

  def compute_fingerprint
    models = ModelIntrospector.discover[:models] || []
    api_routes = RouteIntrospector.api_endpoints

    {
      models: models.each_with_object({}) { |m, h|
        h[m[:name]] = (m[:columns] || []).map { |c| c[:name] }
      },
      api_routes: api_routes.map { |r| "#{r[:method]} #{r[:path]}" },
      computed_at: Time.current.iso8601
    }
  end

  def build_auto_input_schema(model_info)
    properties = {}

    # Add filterable columns
    (model_info[:columns] || []).each do |col|
      next if col[:name].in?(%w[id created_at updated_at encrypted_password reset_password_token])
      next if col[:type] == "jsonb" || col[:type] == "text"

      properties[col[:name]] = {
        type: map_column_type(col[:type]),
        description: "Filter by #{col[:name].humanize.downcase}"
      }
    end

    properties["limit"] = { type: "integer", description: "Max results (default 20)" }

    { type: "object", properties: properties }
  end

  def map_column_type(ar_type)
    case ar_type.to_s
    when "integer", "bigint" then "integer"
    when "float", "decimal" then "number"
    when "boolean" then "boolean"
    when "date", "datetime" then "string"
    else "string"
    end
  end
end
