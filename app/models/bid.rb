class Bid < ApplicationRecord
  belongs_to :client, optional: true
  belongs_to :project, optional: true
  has_many :line_items, class_name: "BidLineItem", dependent: :destroy
  has_many :bid_apps, dependent: :destroy
  has_many :apps, through: :bid_apps
  has_one :invoice

  accepts_nested_attributes_for :bid_apps, allow_destroy: true, reject_if: ->(attrs) { attrs[:app_id].blank? && attrs[:new_app_name].blank? }

  validates :title, presence: true
  validates :status, inclusion: { in: %w[draft sent accepted rejected] }

  # Wizard steps
  WIZARD_STEPS = %w[describe clarify generate costs review].freeze

  # Scopes
  scope :ai_generated, -> { where(ai_generated: true) }
  scope :manual, -> { where(ai_generated: false) }

  # Line item helpers
  def development_line_items
    line_items.development
  end

  def system_cost_line_items
    line_items.system_costs
  end

  # Internal view helpers (for admin only, never shown in PDF)
  def development_items_by_category
    development_line_items.order(:position).group_by(&:work_category_label)
  end

  def hours_by_category
    result = {}
    development_line_items.each do |item|
      label = item.work_category_label
      result[label] ||= 0
      result[label] += item.hours.to_f
    end
    result
  end

  # Subtotal calculations
  def development_subtotal
    development_line_items.sum(:subtotal)
  end

  def system_costs_subtotal
    system_cost_line_items.sum(:subtotal)
  end

  def development_hours_total
    development_line_items.sum(:hours)
  end

  def recalculate_total!
    self.estimated_hours_total = development_hours_total
    self.monthly_costs_total = system_cost_line_items.sum(:display_price)
    self.total = development_subtotal + system_costs_subtotal
    save!
  end

  # Wizard state helpers
  def current_wizard_step
    wizard_state["current_step"] || "describe"
  end

  def current_wizard_step=(step)
    self.wizard_state = wizard_state.merge("current_step" => step)
  end

  def wizard_answers
    wizard_state["answers"] || {}
  end

  def wizard_answers=(answers)
    self.wizard_state = wizard_state.merge("answers" => answers)
  end

  def wizard_questions
    wizard_state["questions"] || []
  end

  def wizard_questions=(questions)
    self.wizard_state = wizard_state.merge("questions" => questions)
  end

  def project_description
    wizard_state["project_description"] || ""
  end

  def project_description=(desc)
    self.wizard_state = wizard_state.merge("project_description" => desc)
  end

  def suggested_items
    wizard_state["suggested_items"] || []
  end

  def suggested_items=(items)
    self.wizard_state = wizard_state.merge("suggested_items" => items)
  end

  def wizard_complete?
    current_wizard_step == "complete"
  end
end
