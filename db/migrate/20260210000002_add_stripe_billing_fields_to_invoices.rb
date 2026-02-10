class AddStripeBillingFieldsToInvoices < ActiveRecord::Migration[7.2]
  def change
    add_reference :invoices, :recurring_invoice, null: true, foreign_key: true
    add_column :invoices, :stripe_hosted_invoice_url, :string
    add_column :invoices, :stripe_payment_intent_id, :string
    add_column :invoices, :stripe_status, :string
    add_column :invoices, :paid_at, :datetime
    add_column :invoices, :due_date, :date
    add_column :invoices, :collection_method, :string
  end
end
