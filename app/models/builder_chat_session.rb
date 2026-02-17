class BuilderChatSession < ApplicationRecord
  belongs_to :user
  belongs_to :agent, optional: true
  belongs_to :builder_agent, class_name: "Agent"

  has_many :agent_executions, dependent: :nullify

  validates :status, presence: true, inclusion: { in: %w[active archived] }

  scope :active, -> { where(status: "active") }
  scope :archived, -> { where(status: "archived") }
  scope :for_agent, ->(agent) { where(agent: agent) }

  def append_message(role:, content:, metadata: {})
    messages = conversation_memory || []
    messages << {
      role: role.to_s,
      content: content,
      timestamp: Time.current.iso8601,
      metadata: metadata
    }
    update!(conversation_memory: messages, last_message_at: Time.current)
  end

  def messages_for_display
    (conversation_memory || []).map do |msg|
      {
        role: msg["role"],
        content: msg["content"],
        timestamp: msg["timestamp"] ? Time.parse(msg["timestamp"]) : nil,
        metadata: msg["metadata"] || {}
      }
    end
  end

  def archive!
    update!(status: "archived")
  end

  def current_execution
    agent_executions.where(status: %w[pending running awaiting_approval]).order(created_at: :desc).first
  end
end
