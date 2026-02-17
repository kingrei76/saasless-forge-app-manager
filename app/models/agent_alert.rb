class AgentAlert < ApplicationRecord
  belongs_to :agent, optional: true
  belongs_to :agent_execution, optional: true
  belongs_to :agent_execution_step, optional: true
  belongs_to :resolved_by, class_name: "User", optional: true

  validates :alert_type, presence: true,
    inclusion: { in: %w[error timeout budget_exceeded approval_needed anomaly] }
  validates :severity, inclusion: { in: %w[info warning error critical] }
  validates :title, presence: true
  validates :status, inclusion: { in: %w[open acknowledged resolved dismissed] }

  scope :open_alerts, -> { where(status: "open") }
  scope :unresolved, -> { where(status: %w[open acknowledged]) }
  scope :by_severity, ->(s) { where(severity: s) }
  scope :by_type, ->(t) { where(alert_type: t) }
  scope :recent, -> { order(created_at: :desc) }

  ALERT_TYPES = %w[error timeout budget_exceeded approval_needed anomaly].freeze
  SEVERITIES = %w[info warning error critical].freeze
  STATUSES = %w[open acknowledged resolved dismissed].freeze

  def acknowledge!(user = nil)
    update!(status: "acknowledged")
  end

  def resolve!(user = nil)
    update!(status: "resolved", resolved_at: Time.current, resolved_by: user)
  end

  def dismiss!(user = nil)
    update!(status: "dismissed", resolved_at: Time.current, resolved_by: user)
  end

  def severity_badge_color
    case severity
    when "critical" then "error"
    when "error"    then "error"
    when "warning"  then "warning"
    else "info"
    end
  end
end
