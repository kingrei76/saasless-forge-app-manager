class AgentExecutionStep < ApplicationRecord
  belongs_to :agent_execution
  belongs_to :tool_definition, optional: true
  belongs_to :target_agent, class_name: "Agent", optional: true

  has_many :agent_alerts, dependent: :nullify

  validates :step_number, presence: true, uniqueness: { scope: :agent_execution_id }
  validates :step_type, presence: true,
    inclusion: { in: %w[llm_call tool_call handoff approval_request decision] }
  validates :status, inclusion: { in: %w[pending running completed failed skipped approved rejected] }

  scope :ordered, -> { order(step_number: :asc) }
  scope :by_type, ->(t) { where(step_type: t) }
  scope :completed, -> { where(status: "completed") }

  STEP_TYPES = %w[llm_call tool_call handoff approval_request decision].freeze
  STATUSES = %w[pending running completed failed skipped approved rejected].freeze

  def step_type_icon
    case step_type
    when "llm_call"         then "fa-brain"
    when "tool_call"        then "fa-wrench"
    when "handoff"          then "fa-exchange-alt"
    when "approval_request" then "fa-hand-paper"
    when "decision"         then "fa-code-branch"
    else "fa-circle"
    end
  end

  def status_badge_color
    case status
    when "completed" then "success"
    when "running"   then "info"
    when "pending"   then "ghost"
    when "failed"    then "error"
    when "approved"  then "success"
    when "rejected"  then "error"
    when "skipped"   then "ghost"
    else "info"
    end
  end
end
