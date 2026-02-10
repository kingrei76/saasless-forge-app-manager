class CreateInvoices < ActiveRecord::Migration[7.2]
  def change
    create_table :invoices do |t|
      t.references :client, null: false, foreign_key: true
      t.string :stripe_invoice_id
      t.string :status, default: "draft"
      t.date :period_start
      t.date :period_end
      t.decimal :subtotal, precision: 10, scale: 2, default: 0
      t.decimal :total, precision: 10, scale: 2, default: 0

      t.timestamps
    end
  end
end
