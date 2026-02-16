class Client < ApplicationRecord
  has_many :app_assignments, dependent: :destroy
  has_many :apps, through: :app_assignments
  has_many :invoices, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :bids, dependent: :nullify
  has_many :calculated_costs, dependent: :destroy
  has_one :recurring_invoice, dependent: :destroy
  has_many :pending_billing_items, dependent: :destroy

  COLLECTION_METHODS = %w[send_invoice charge_automatically].freeze

  validates :name, presence: true
  validates :collection_method, inclusion: { in: COLLECTION_METHODS }, allow_nil: true

  def effective_markup
    markup_percentage || Setting[:default_markup_percentage].to_f
  end

  # Billing cycle methods

  def has_stripe_subscription?
    stripe_subscription_id.present?
  end

  def current_billing_period
    if billing_anchor.present? && billing_day_of_month.present?
      calculate_billing_period_from_anchor
    else
      # Default to calendar month if no Stripe data
      [Date.current.beginning_of_month, Date.current.end_of_month]
    end
  end

  def billing_period_for_date(date)
    if billing_anchor.present? && billing_day_of_month.present?
      calculate_billing_period_from_anchor(date)
    else
      [date.beginning_of_month, date.end_of_month]
    end
  end

  def days_into_billing_cycle
    start_date, _ = current_billing_period
    (Date.current - start_date).to_i + 1
  end

  def days_in_current_billing_cycle
    start_date, end_date = current_billing_period
    (end_date - start_date).to_i + 1
  end

  def billing_cycle_progress_percentage
    (days_into_billing_cycle.to_f / days_in_current_billing_cycle * 100).round(1)
  end

  private

  def calculate_billing_period_from_anchor(reference_date = Date.current)
    day = billing_day_of_month

    # Find the billing period that contains the reference date
    if reference_date.day >= day
      period_start = Date.new(reference_date.year, reference_date.month, day)
      period_end = period_start.next_month - 1.day
    else
      period_end = Date.new(reference_date.year, reference_date.month, day) - 1.day
      period_start = period_end.prev_month + 1.day
    end

    # Handle edge cases for months with fewer days
    [period_start, period_end]
  rescue ArgumentError
    # If the day doesn't exist in the month, use the last day
    [reference_date.beginning_of_month, reference_date.end_of_month]
  end
end
