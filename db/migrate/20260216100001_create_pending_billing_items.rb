class CreatePendingBillingItems < ActiveRecord::Migration[7.2]
  def change
    create_table :pending_billing_items do |t|
      t.references :client, null: false, foreign_key: true
      t.references :app, foreign_key: true
      t.string :stripe_invoice_item_id, null: false
      t.string :item_type, null: false
      t.string :description
      t.decimal :internal_cost, precision: 10, scale: 2
      t.decimal :markup_percentage, precision: 5, scale: 2
      t.decimal :billed_amount, precision: 10, scale: 2
      t.date :period_start
      t.date :period_end
      t.string :billing_cycle_id
      t.string :status, default: "pending", null: false
      t.string :stripe_invoice_id
      t.timestamps
    end

    add_index :pending_billing_items, :stripe_invoice_item_id, unique: true
    add_index :pending_billing_items, [:client_id, :billing_cycle_id]
    add_index :pending_billing_items, :status
  end
end
