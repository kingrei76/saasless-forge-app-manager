class RenderPrice < ApplicationRecord
  validates :service_type, presence: true
  validates :plan_name, presence: true
  validates :monthly_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :effective_from, presence: true

  scope :current, -> { where(effective_until: nil) }
  scope :for_service, ->(type) { where(service_type: type) }
  scope :for_plan, ->(plan) { where(plan_name: plan) }

  def self.lookup(service_type:, plan_name:, date: Date.current)
    where(service_type: service_type, plan_name: plan_name)
      .where("effective_from <= ?", date)
      .where("effective_until IS NULL OR effective_until >= ?", date)
      .order(effective_from: :desc)
      .first
  end

  def self.current_price(service_type:, plan_name:)
    current.for_service(service_type).for_plan(plan_name).first&.monthly_price || 0
  end
end
