class Invoice < ApplicationRecord
  belongs_to :client
  belongs_to :project, optional: true
  belongs_to :bid, optional: true
  belongs_to :parent_invoice, class_name: "Invoice", optional: true
  belongs_to :recurring_invoice, optional: true

  has_many :line_items, class_name: "InvoiceLineItem", dependent: :destroy
  has_one :child_invoice, class_name: "Invoice", foreign_key: :parent_invoice_id

  # Payment types:
  # - "deposit" = 50% upfront for project (has project_id)
  # - "final" = remaining 50% on project completion (has project_id)
  # - "infrastructure" = monthly client costs (NO project_id, just client_id)
  # - "full" = legacy/one-time full payment
  PAYMENT_TYPES = %w[deposit final infrastructure full].freeze
  STATUSES = %w[draft sent paid void overdue failed archived].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :invoice_type, inclusion: { in: %w[bid_based cost_based] }
  validates :payment_type, inclusion: { in: PAYMENT_TYPES }, allow_nil: true

  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :visible, -> { where.not(status: "archived") }
  scope :bid_based, -> { where(invoice_type: "bid_based") }
  scope :cost_based, -> { where(invoice_type: "cost_based") }
  scope :deposits, -> { where(payment_type: "deposit") }
  scope :finals, -> { where(payment_type: "final") }
  scope :infrastructure, -> { where(payment_type: "infrastructure") }
  scope :project_invoices, -> { where(payment_type: %w[deposit final]) }

  def recalculate_totals!
    if invoice_type == "bid_based"
      self.subtotal = line_items.sum { |li| (li.hours || 0) * (li.rate || 0) }
      self.total = subtotal
    else
      self.subtotal = line_items.sum(:internal_cost)
      self.total = line_items.sum(:amount)
    end
    save!
  end

  def deposit?
    payment_type == "deposit"
  end

  def final?
    payment_type == "final"
  end

  def infrastructure?
    payment_type == "infrastructure"
  end

  def payment_type_label
    case payment_type
    when "deposit" then "50% Deposit"
    when "final" then "Final Payment"
    when "infrastructure" then "Monthly Infrastructure"
    else "Full Payment"
    end
  end

  def mark_deposit_paid!
    return unless deposit?
    update!(deposit_paid_at: Time.current)
  end

  def mark_final_paid!
    return unless final?
    update!(final_paid_at: Time.current)
  end

  def mark_paid_from_stripe!(timestamp = Time.current)
    update!(
      status: "paid",
      paid_at: timestamp,
      stripe_status: "paid"
    )
    mark_deposit_paid! if deposit?
    mark_final_paid! if final?
  end

  def mark_failed!
    update!(status: "failed", stripe_status: "payment_failed")
  end

  def mark_overdue!
    update!(status: "overdue", stripe_status: "overdue")
  end

  def stripe_payment_url
    stripe_hosted_invoice_url
  end

  def archive!
    update!(status: "archived")
  end

  def stripe_managed?
    stripe_invoice_id.present?
  end

  def status_badge_class
    {
      "draft" => "badge-ghost",
      "sent" => "badge-info",
      "paid" => "badge-success",
      "void" => "badge-error",
      "overdue" => "badge-warning",
      "failed" => "badge-error",
      "archived" => "badge-neutral"
    }[status] || "badge-ghost"
  end
end
