class InvoiceLineItem < ApplicationRecord
  belongs_to :invoice
  belongs_to :app, optional: true

  before_save :calculate_amount

  private

  def calculate_amount
    if invoice&.invoice_type == "bid_based"
      self.amount = (hours || 0) * (rate || 0)
    else
      return unless internal_cost && markup_percentage
      self.amount = internal_cost * (1 + markup_percentage / 100.0)
    end
  end
end
