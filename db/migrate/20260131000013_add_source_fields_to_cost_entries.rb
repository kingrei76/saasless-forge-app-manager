class AddSourceFieldsToCostEntries < ActiveRecord::Migration[7.2]
  def change
    add_column :cost_entries, :source_type, :string
    add_column :cost_entries, :source_id, :string

    add_index :cost_entries, [:source_type, :source_id, :period_start], unique: true, name: "idx_cost_entries_source_period"
  end
end
