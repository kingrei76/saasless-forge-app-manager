class CreateProjectApps < ActiveRecord::Migration[7.2]
  def change
    create_table :project_apps do |t|
      t.references :project, null: false, foreign_key: true
      t.references :app, foreign_key: true
      t.string :new_app_name  # For apps that don't exist yet
      t.boolean :primary, default: false  # Mark the main app for the project

      t.timestamps
    end

    add_index :project_apps, [:project_id, :app_id], unique: true, where: "app_id IS NOT NULL"
  end
end
