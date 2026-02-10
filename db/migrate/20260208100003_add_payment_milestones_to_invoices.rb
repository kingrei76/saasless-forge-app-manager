class AddPaymentMilestonesToInvoices < ActiveRecord::Migration[7.2]
  def change
    add_column :invoices, :payment_type, :string, default: "full"
    add_column :invoices, :deposit_percentage, :decimal, precision: 5, scale: 2
    add_column :invoices, :deposit_amount, :decimal, precision: 10, scale: 2
    add_column :invoices, :deposit_paid_at, :datetime
    add_column :invoices, :final_amount, :decimal, precision: 10, scale: 2
    add_column :invoices, :final_paid_at, :datetime
    add_column :invoices, :parent_invoice_id, :bigint

    add_index :invoices, :payment_type
    add_index :invoices, :parent_invoice_id
  end
end
