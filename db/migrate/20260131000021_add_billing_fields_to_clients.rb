class AddBillingFieldsToClients < ActiveRecord::Migration[7.2]
  def change
    add_column :clients, :billing_anchor, :date
    add_column :clients, :billing_day_of_month, :integer
    add_column :clients, :stripe_subscription_id, :string
    add_column :clients, :billing_cycle_last_synced_at, :datetime

    add_index :clients, :stripe_subscription_id, unique: true
  end
end
