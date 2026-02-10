class Project < ApplicationRecord
  belongs_to :client
  belongs_to :assignee, class_name: "User", optional: true
  belongs_to :source_bid, class_name: "Bid", optional: true

  has_many :bids, dependent: :destroy
  has_many :invoices, dependent: :nullify
  has_many :time_entries, dependent: :destroy
  has_many :project_apps, dependent: :destroy
  has_many :apps, through: :project_apps

  has_one_attached :requirements_doc
  has_one_attached :signed_contract

  # Project stages for workflow
  STAGES = %w[in_development testing deployed adopted complete].freeze

  STAGE_LABELS = {
    "in_development" => "In Development",
    "testing" => "Testing",
    "deployed" => "Deployed",
    "adopted" => "Adopted",
    "complete" => "Complete"
  }.freeze

  validates :title, presence: true
  validates :status, inclusion: { in: %w[active on_hold completed cancelled] }
  validates :stage, inclusion: { in: STAGES }, allow_nil: true

  scope :active, -> { where(status: "active") }
  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :by_stage, ->(stage) { where(stage: stage) if stage.present? }
  scope :in_progress, -> { where.not(stage: "complete") }
  scope :completed, -> { where(stage: "complete") }

  def stage_label
    STAGE_LABELS[stage] || stage&.titleize || "Unknown"
  end

  def stage_index
    STAGES.index(stage) || 0
  end

  def can_advance_stage?
    stage.present? && stage != "complete" && stage != "adopted"
  end

  def can_complete?
    stage == "adopted"
  end

  def next_stage
    return nil unless can_advance_stage?
    current_index = STAGES.index(stage)
    return nil if current_index.nil? || current_index >= STAGES.length - 1
    STAGES[current_index + 1]
  end

  def advance_stage!
    return false unless can_advance_stage?
    next_stage_value = next_stage
    return false unless next_stage_value
    update!(stage: next_stage_value)
  end

  def recalculate_actual_hours!
    update_column(:actual_hours, time_entries.sum(:hours))
  end

  def hours_variance
    return nil unless estimated_hours.present? && estimated_hours > 0
    actual_hours.to_f - estimated_hours.to_f
  end

  def hours_variance_percentage
    return nil unless estimated_hours.present? && estimated_hours > 0
    ((actual_hours.to_f - estimated_hours.to_f) / estimated_hours.to_f * 100).round(1)
  end

  def deposit_invoice
    invoices.find_by(payment_type: "deposit")
  end

  def final_invoice
    invoices.find_by(payment_type: "final")
  end

  def hours_by_category
    time_entries.group(:work_category).sum(:hours)
  end

  # App-related methods
  def primary_app
    project_apps.primary.first&.app || apps.first
  end

  def has_linked_app?
    project_apps.with_app.exists?
  end

  def has_pending_apps?
    project_apps.pending_creation.exists?
  end

  def needs_app_mapping?
    !has_linked_app? && project_apps.any?
  end

  # Fetch recent commits from the primary app's GitHub repo
  def recent_commits(limit: 10)
    app = primary_app
    return [] unless app&.github_account&.access_token.present?
    return [] unless app.full_name.present?

    github = GithubApiService.new(access_token: app.github_account.access_token)
    github.commits(repo: app.full_name, per_page: limit)
  rescue StandardError => e
    Rails.logger.error("Failed to fetch commits for project #{id}: #{e.message}")
    []
  end
end
