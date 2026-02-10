class AddRenderFieldsToApps < ActiveRecord::Migration[7.2]
  def change
    add_column :apps, :render_service_id, :string
    add_column :apps, :render_service_type, :string
    add_column :apps, :render_plan, :string
    add_column :apps, :render_owner_id, :string
    add_column :apps, :render_created_at, :datetime

    add_index :apps, :render_service_id, unique: true
    add_index :apps, :render_owner_id
  end
end
