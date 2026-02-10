class TimeEntry < ApplicationRecord
  belongs_to :project
  belongs_to :user

  # Work categories (same as BidLineItem for consistency)
  WORK_CATEGORIES = %w[
    discovery_planning
    development
    integration
    testing_qa
    deployment_devops
  ].freeze

  WORK_CATEGORY_LABELS = {
    "discovery_planning" => "Discovery & Planning",
    "development" => "Development",
    "integration" => "Integration",
    "testing_qa" => "Testing & QA",
    "deployment_devops" => "Deployment & DevOps"
  }.freeze

  validates :entry_date, presence: true
  validates :hours, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 24 }
  validates :work_category, presence: true, inclusion: { in: WORK_CATEGORIES }

  after_save :update_project_actual_hours
  after_destroy :update_project_actual_hours

  scope :by_category, ->(category) { where(work_category: category) if category.present? }
  scope :for_date_range, ->(start_date, end_date) { where(entry_date: start_date..end_date) }

  def work_category_label
    WORK_CATEGORY_LABELS[work_category] || work_category&.titleize || "Uncategorized"
  end

  private

  def update_project_actual_hours
    project.recalculate_actual_hours!
  end
end
