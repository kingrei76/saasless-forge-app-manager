class AgentTool < ApplicationRecord
  belongs_to :agent
  belongs_to :tool_definition

  validates :agent_id, uniqueness: { scope: :tool_definition_id }

  scope :enabled, -> { where(enabled: true) }
  scope :requiring_approval, -> { where(requires_approval: true) }
  scope :ordered, -> { order(position: :asc) }
end
