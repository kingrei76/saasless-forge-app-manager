class CreateAppAssignments < ActiveRecord::Migration[7.2]
  def change
    create_table :app_assignments do |t|
      t.references :app, null: false, foreign_key: true
      t.references :client, null: false, foreign_key: true
      t.decimal :markup_percentage, precision: 5, scale: 2

      t.timestamps
    end

    add_index :app_assignments, [:app_id, :client_id], unique: true
  end
end
