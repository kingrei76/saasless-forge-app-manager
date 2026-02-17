class AgentHandoff < ApplicationRecord
  belongs_to :source_agent, class_name: "Agent"
  belongs_to :target_agent, class_name: "Agent"

  validates :source_agent_id, uniqueness: { scope: :target_agent_id }
  validate :no_self_handoff

  scope :enabled, -> { where(enabled: true) }
  scope :ordered, -> { order(priority: :asc) }

  private

  def no_self_handoff
    errors.add(:target_agent_id, "cannot hand off to itself") if source_agent_id == target_agent_id
  end
end
