class CreateCalculatedCosts < ActiveRecord::Migration[7.2]
  def change
    create_table :calculated_costs do |t|
      t.references :app, null: false, foreign_key: true
      t.references :client, null: false, foreign_key: true
      t.string :render_service_id
      t.string :service_type           # web_service, postgres, redis, cron
      t.string :plan_name              # starter, standard, pro, etc.

      # Billing period (aligned to client's Stripe subscription)
      t.date :billing_period_start, null: false
      t.date :billing_period_end, null: false

      # Cost breakdown
      t.decimal :base_cost, precision: 10, scale: 2, default: 0
      t.decimal :bandwidth_cost, precision: 10, scale: 2, default: 0
      t.decimal :storage_cost, precision: 10, scale: 2, default: 0
      t.decimal :total_cost, precision: 10, scale: 2, default: 0

      # Proration info
      t.integer :days_in_period
      t.integer :days_active
      t.decimal :prorated_multiplier, precision: 6, scale: 4, default: 1.0

      # Projections
      t.decimal :projected_monthly_cost, precision: 10, scale: 2

      t.timestamps
    end

    add_index :calculated_costs, [:app_id, :client_id, :render_service_id, :billing_period_start],
              name: "idx_calculated_costs_lookup",
              unique: true
    add_index :calculated_costs, [:client_id, :billing_period_start],
              name: "idx_calculated_costs_by_client"
  end
end
