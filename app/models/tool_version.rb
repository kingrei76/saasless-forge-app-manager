class ToolVersion < ApplicationRecord
  belongs_to :tool_definition
  belongs_to :created_by, class_name: "User", optional: true

  validates :version_number, presence: true, uniqueness: { scope: :tool_definition_id }

  scope :ordered, -> { order(version_number: :desc) }
end
