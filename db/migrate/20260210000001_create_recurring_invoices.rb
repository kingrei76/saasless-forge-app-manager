class CreateRecurringInvoices < ActiveRecord::Migration[7.2]
  def change
    create_table :recurring_invoices do |t|
      t.references :client, null: false, foreign_key: true, index: { unique: true }
      t.string :status, default: "draft", null: false
      t.string :collection_method, default: "send_invoice", null: false
      t.integer :days_until_due, default: 30
      t.integer :billing_day_of_month, default: 1
      t.date :next_billing_date
      t.date :last_billed_date
      t.string :stripe_payment_method_id
      t.text :notes

      t.timestamps
    end

    add_index :recurring_invoices, [:status, :next_billing_date]
  end
end
