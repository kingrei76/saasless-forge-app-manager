class RecurringInvoice < ApplicationRecord
  belongs_to :client
  has_many :invoices, dependent: :nullify

  STATUSES = %w[draft active paused cancelled].freeze
  COLLECTION_METHODS = %w[send_invoice charge_automatically].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :collection_method, inclusion: { in: COLLECTION_METHODS }
  validates :billing_day_of_month, numericality: { in: 1..28 }
  validates :client_id, uniqueness: true
  validates :days_until_due, numericality: { greater_than: 0 }, if: -> { collection_method == "send_invoice" }

  scope :active, -> { where(status: "active") }
  scope :due_today, -> { active.where("next_billing_date <= ?", Date.current) }

  # Auto-create recurring invoices for clients with billable app assignments
  # that don't already have a recurring invoice configured.
  def self.ensure_for_billable_clients!
    existing_client_ids = RecurringInvoice.pluck(:client_id)

    Client.includes(app_assignments: { app: :render_services }).find_each do |client|
      next if existing_client_ids.include?(client.id)
      next unless client.app_assignments.any? { |aa| aa.app.included? }

      RecurringInvoice.create!(
        client: client,
        status: "draft",
        collection_method: "send_invoice",
        billing_day_of_month: 1,
        days_until_due: 30
      )
    end
  end

  def activate!
    compute_next_billing_date! if next_billing_date.blank?
    update!(status: "active")
  end

  def pause!
    update!(status: "paused")
  end

  def cancel!
    update!(status: "cancelled")
  end

  def compute_next_billing_date!
    if last_billed_date.present?
      next_date = last_billed_date.next_month
      next_date = Date.new(next_date.year, next_date.month, [billing_day_of_month, next_date.end_of_month.day].min)
    else
      # First run: bill for the previous month at the start of next month
      today = Date.current
      if today.day >= billing_day_of_month
        next_date = today.next_month
        next_date = Date.new(next_date.year, next_date.month, [billing_day_of_month, next_date.end_of_month.day].min)
      else
        next_date = Date.new(today.year, today.month, [billing_day_of_month, today.end_of_month.day].min)
      end
    end

    update!(next_billing_date: next_date)
  end

  def billing_period_for_next_run
    # Returns the previous month's date range (what we're billing for)
    target = next_billing_date || Date.current
    period_end = target - 1.day
    period_start = period_end.beginning_of_month
    period_end = period_end.end_of_month
    [period_start, period_end]
  end

  def send_invoice?
    collection_method == "send_invoice"
  end

  def charge_automatically?
    collection_method == "charge_automatically"
  end

  def status_badge_class
    case status
    when "active" then "badge-success"
    when "paused" then "badge-warning"
    when "cancelled" then "badge-error"
    else "badge-ghost"
    end
  end
end
