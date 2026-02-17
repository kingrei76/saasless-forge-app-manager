class AgentTrigger < ApplicationRecord
  belongs_to :agent
  belongs_to :depends_on_agent, class_name: "Agent", optional: true
  belongs_to :tool_definition, optional: true

  validates :trigger_type, presence: true,
    inclusion: { in: %w[event schedule data dependency webhook manual] }
  validates :tool_definition, presence: true, if: -> { trigger_type == "data" }
  validates :schedule, presence: true, if: -> { trigger_type == "schedule" }

  scope :enabled, -> { where(enabled: true) }
  scope :by_type, ->(t) { where(trigger_type: t) }

  before_create :generate_webhook_token, if: -> { trigger_type == "webhook" }

  TRIGGER_TYPES = %w[event schedule data dependency webhook manual].freeze

  SCHEDULE_PRESETS = {
    "every_minute" => "* * * * *",
    "every_5_minutes" => "*/5 * * * *",
    "every_15_minutes" => "*/15 * * * *",
    "every_30_minutes" => "*/30 * * * *",
    "every_hour" => "0 * * * *",
    "every_6_hours" => "0 */6 * * *",
    "every_12_hours" => "0 */12 * * *",
    "every_day" => "0 9 * * *",
    "every_weekday" => "0 9 * * 1-5",
    "every_week" => "0 9 * * 1",
    "every_month" => "0 9 1 * *"
  }.freeze

  def evaluate_condition(data)
    return true if condition.blank? || condition == {}
    AgentTriggerService.evaluate_conditions(condition, data)
  end

  def should_check_now?
    return false unless trigger_type == "data"
    return true if last_checked_at.nil?
    last_checked_at <= check_interval_minutes.minutes.ago
  end

  def within_cooldown?
    return false if cooldown_minutes.to_i.zero?
    return false if last_fired_at.nil?
    last_fired_at > cooldown_minutes.minutes.ago
  end

  def fire!(input_data = {})
    return false if within_cooldown?

    merged_data = (input_data_template || {}).merge(input_data)

    execution = AgentExecution.create!(
      agent: agent,
      trigger: self,
      status: "pending",
      mode: agent.mode,
      input_data: merged_data
    )

    AgentExecutionJob.perform_later(execution.id)
    update!(last_fired_at: Time.current)

    execution
  end

  def cron_expression
    SCHEDULE_PRESETS[schedule] || schedule
  end

  def webhook_url
    return nil unless webhook_token.present?
    base = Setting[:app_base_url] || ENV["APP_BASE_URL"] || "http://localhost:3000"
    "#{base}/api/triggers/#{webhook_token}"
  end

  private

  def generate_webhook_token
    self.webhook_token ||= SecureRandom.urlsafe_base64(32)
  end
end
