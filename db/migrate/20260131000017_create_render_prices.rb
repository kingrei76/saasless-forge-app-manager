class CreateRenderPrices < ActiveRecord::Migration[7.2]
  def change
    create_table :render_prices do |t|
      t.string :service_type, null: false  # web_service, postgres, redis, cron, static_site
      t.string :plan_name, null: false     # free, starter, standard, pro, etc.
      t.decimal :monthly_price, precision: 10, scale: 2, null: false
      t.decimal :bandwidth_overage_per_gb, precision: 10, scale: 4  # cost per GB over included
      t.decimal :storage_overage_per_gb, precision: 10, scale: 4    # cost per GB over included
      t.integer :included_bandwidth_gb      # included bandwidth in plan
      t.integer :included_storage_gb        # included storage in plan
      t.date :effective_from, null: false
      t.date :effective_until               # nil = current pricing

      t.timestamps
    end

    add_index :render_prices, [:service_type, :plan_name, :effective_from],
              name: "idx_render_prices_lookup",
              unique: true
  end
end
