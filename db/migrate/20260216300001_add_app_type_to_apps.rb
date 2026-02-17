class AddAppTypeToApps < ActiveRecord::Migration[7.2]
  def change
    add_column :apps, :app_type, :string, default: "client_app", null: false
    add_index :apps, :app_type
  end
end
