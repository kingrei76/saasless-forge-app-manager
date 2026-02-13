class CreateServiceGatewayTables < ActiveRecord::Migration[7.2]
  def change
    create_table :service_providers do |t|
      t.string   :name, null: false
      t.string   :slug, null: false, index: { unique: true }
      t.string   :category, null: false
      t.string   :base_url
      t.string   :api_key
      t.string   :usage_api_key
      t.jsonb    :pricing_rules, default: {}
      t.string   :sync_adapter
      t.jsonb    :sync_config, default: {}
      t.boolean  :proxy_enabled, default: false
      t.boolean  :sync_enabled, default: false
      t.boolean  :active, default: true
      t.datetime :last_synced_at
      t.timestamps
    end

    create_table :app_service_configs do |t|
      t.references :app, null: false, foreign_key: true
      t.references :service_provider, null: false, foreign_key: true
      t.boolean    :enabled, default: true
      t.decimal    :monthly_budget_limit, precision: 10, scale: 2
      t.string     :external_identifier
      t.jsonb      :config, default: {}
      t.timestamps

      t.index [:app_id, :service_provider_id], unique: true, name: "idx_app_service_configs_unique"
    end

    add_reference :api_usage_logs, :service_provider, foreign_key: true
    add_column :api_usage_logs, :quantity, :integer
    add_column :api_usage_logs, :quantity_unit, :string
    add_column :api_usage_logs, :metadata, :jsonb, default: {}
    add_column :api_usage_logs, :external_id, :string
    add_index :api_usage_logs, :external_id, unique: true, where: "external_id IS NOT NULL"
  end
end
