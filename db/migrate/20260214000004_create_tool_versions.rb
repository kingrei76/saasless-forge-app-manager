class CreateToolVersions < ActiveRecord::Migration[7.2]
  def change
    create_table :tool_versions do |t|
      t.references :tool_definition, null: false, foreign_key: true
      t.integer :version_number, null: false
      t.text :description
      t.jsonb :input_schema, default: {}
      t.jsonb :config_snapshot, default: {}
      t.text :change_summary
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :tool_versions, [:tool_definition_id, :version_number], unique: true, name: "idx_tool_versions_unique"
  end
end
