class CreateAgentVersions < ActiveRecord::Migration[7.2]
  def change
    create_table :agent_versions do |t|
      t.references :agent, null: false, foreign_key: true
      t.integer :version_number, null: false
      t.text :system_prompt
      t.jsonb :config_snapshot, default: {}
      t.text :change_summary
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :agent_versions, [:agent_id, :version_number], unique: true
  end
end
