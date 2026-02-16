class PendingBillingItem < ApplicationRecord
  belongs_to :client
  belongs_to :app, optional: true

  validates :stripe_invoice_item_id, presence: true, uniqueness: true
  validates :item_type, presence: true, inclusion: { in: %w[infrastructure ai_usage] }
  validates :status, presence: true, inclusion: { in: %w[pending invoiced void] }

  scope :pending, -> { where(status: "pending") }
  scope :invoiced, -> { where(status: "invoiced") }
  scope :for_cycle, ->(cycle_id) { where(billing_cycle_id: cycle_id) }
  scope :for_client, ->(client) { where(client: client) }

  def pending?
    status == "pending"
  end

  def invoiced?
    status == "invoiced"
  end

  def mark_invoiced!(stripe_invoice_id)
    update!(status: "invoiced", stripe_invoice_id: stripe_invoice_id)
  end

  def void!
    update!(status: "void")
  end
end
