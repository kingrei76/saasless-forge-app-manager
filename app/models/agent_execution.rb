class AgentExecution < ApplicationRecord
  belongs_to :agent
  belongs_to :parent_execution, class_name: "AgentExecution", optional: true
  belongs_to :trigger, class_name: "AgentTrigger", optional: true
  belongs_to :builder_chat_session, optional: true

  has_many :steps, class_name: "AgentExecutionStep", dependent: :destroy
  has_many :child_executions, class_name: "AgentExecution", foreign_key: :parent_execution_id, dependent: :nullify
  has_many :agent_alerts, dependent: :nullify

  validates :status, presence: true,
    inclusion: { in: %w[pending running awaiting_approval completed failed cancelled timed_out] }
  validates :mode, inclusion: { in: %w[test live] }

  scope :by_status, ->(s) { where(status: s) }
  scope :running, -> { where(status: "running") }
  scope :completed, -> { where(status: "completed") }
  scope :failed, -> { where(status: "failed") }
  scope :recent, -> { order(created_at: :desc) }
  scope :today, -> { where("agent_executions.created_at >= ?", Time.current.beginning_of_day) }

  STATUSES = %w[pending running awaiting_approval completed failed cancelled timed_out].freeze

  def duration
    return nil unless started_at
    (completed_at || Time.current) - started_at
  end

  def duration_display
    secs = duration
    return "N/A" unless secs
    if secs < 60
      "#{secs.round(1)}s"
    elsif secs < 3600
      "#{(secs / 60).round(1)}m"
    else
      "#{(secs / 3600).round(1)}h"
    end
  end

  def status_badge_color
    case status
    when "completed"         then "success"
    when "running"           then "info"
    when "awaiting_approval" then "warning"
    when "failed"            then "error"
    when "cancelled"         then "ghost"
    when "timed_out"         then "error"
    else "info"
    end
  end

  def success?
    status == "completed"
  end

  def in_progress?
    status.in?(%w[pending running awaiting_approval])
  end
end
