class CreateRenderServices < ActiveRecord::Migration[7.2]
  def change
    create_table :render_services do |t|
      t.references :app, null: true, foreign_key: true
      t.string :render_service_id, null: false
      t.string :name, null: false
      t.string :service_type
      t.string :plan
      t.string :render_owner_id
      t.datetime :render_created_at
      t.boolean :suspended, default: false
      t.jsonb :raw_data, default: {}

      t.timestamps
    end

    add_index :render_services, :render_service_id, unique: true
    add_index :render_services, :render_owner_id
    add_index :render_services, :service_type
    add_index :render_services, [:app_id, :service_type], name: "index_render_services_on_app_and_type"
  end
end
