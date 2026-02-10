class CreateRenderUsageMetrics < ActiveRecord::Migration[7.2]
  def change
    create_table :render_usage_metrics do |t|
      t.references :app, null: false, foreign_key: true
      t.string :render_service_id, null: false
      t.string :metric_type, null: false  # cpu, memory, bandwidth, disk
      t.decimal :value, precision: 15, scale: 4, null: false
      t.string :unit, null: false         # percent, bytes, gb, mb
      t.datetime :period_start, null: false
      t.datetime :period_end, null: false
      t.jsonb :raw_data, default: {}

      t.timestamps
    end

    add_index :render_usage_metrics, [:app_id, :render_service_id, :metric_type, :period_start],
              name: "idx_render_usage_metrics_lookup",
              unique: true
    add_index :render_usage_metrics, :render_service_id
    add_index :render_usage_metrics, :metric_type
  end
end
