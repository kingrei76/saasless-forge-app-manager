class AgentVersion < ApplicationRecord
  belongs_to :agent
  belongs_to :created_by, class_name: "User", optional: true

  validates :version_number, presence: true, uniqueness: { scope: :agent_id }

  scope :ordered, -> { order(version_number: :desc) }
  scope :latest, -> { ordered.first }
end
