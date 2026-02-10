class AddProjectFieldsToInvoices < ActiveRecord::Migration[7.2]
  def change
    add_reference :invoices, :project, foreign_key: true
    add_reference :invoices, :bid, foreign_key: { to_table: :bids }
    add_column :invoices, :invoice_type, :string, default: "cost_based"
    add_column :invoice_line_items, :hours, :decimal, precision: 8, scale: 2
    add_column :invoice_line_items, :rate, :decimal, precision: 10, scale: 2
  end
end
