class CreateTimeEntries < ActiveRecord::Migration[7.2]
  def change
    create_table :time_entries do |t|
      t.references :project, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.date :entry_date, null: false
      t.decimal :hours, precision: 6, scale: 2, null: false
      t.string :work_category, null: false
      t.text :notes

      t.timestamps
    end

    add_index :time_entries, [:project_id, :entry_date]
    add_index :time_entries, :work_category
  end
end
