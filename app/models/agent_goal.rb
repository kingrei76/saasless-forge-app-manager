class AgentGoal < ApplicationRecord
  belongs_to :agent

  validates :title, presence: true
  validates :status, inclusion: { in: %w[active completed paused] }

  scope :active, -> { where(status: "active") }
  scope :ordered, -> { order(priority: :asc) }

  STATUSES = %w[active completed paused].freeze
end
