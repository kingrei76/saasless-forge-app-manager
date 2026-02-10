class RenderWorkspace < ApplicationRecord
  has_many :apps, primary_key: :render_owner_id, foreign_key: :render_owner_id

  validates :render_owner_id, presence: true, uniqueness: true
  validates :name, presence: true

  scope :teams, -> { where(workspace_type: "team") }
  scope :users, -> { where(workspace_type: "user") }

  def team?
    workspace_type == "team"
  end

  def display_name
    "#{name} (#{workspace_type || 'unknown'})"
  end
end
