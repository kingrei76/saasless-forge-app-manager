class BidLineItem < ApplicationRecord
  belongs_to :bid
  belongs_to :bid_app, optional: true

  # Line item types
  TYPES = %w[development system_cost].freeze

  # Billing frequencies for recurring costs
  BILLING_FREQUENCIES = %w[monthly annual].freeze

  # Work categories for internal tracking
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

  validates :line_item_type, inclusion: { in: TYPES }
  validates :billing_frequency, inclusion: { in: BILLING_FREQUENCIES }, allow_blank: true
  validates :work_category, inclusion: { in: WORK_CATEGORIES }, allow_blank: true

  # Scopes
  scope :development, -> { where(line_item_type: "development") }
  scope :system_costs, -> { where(line_item_type: "system_cost") }
  scope :recurring, -> { where(is_recurring: true) }

  before_save :calculate_subtotal
  before_save :calculate_display_price

  def development?
    line_item_type == "development"
  end

  def system_cost?
    line_item_type == "system_cost"
  end

  def recurring?
    is_recurring == true
  end

  def work_category_label
    WORK_CATEGORY_LABELS[work_category] || work_category&.titleize || "Uncategorized"
  end

  private

  def calculate_subtotal
    if development?
      # Development items: hours × rate
      self.subtotal = (hours || 0) * (rate || 0)
    else
      # System cost items: use display_price as subtotal (after markup)
      self.subtotal = display_price || 0
    end
  end

  def calculate_display_price
    return unless system_cost? && unit_cost.present?

    # Apply 30% markup to system costs
    markup_percentage = Setting[:default_markup_percentage]&.to_f || 30.0
    self.display_price = MarkupCalculator.apply(cost: unit_cost, markup_percentage: markup_percentage)
  end
end
