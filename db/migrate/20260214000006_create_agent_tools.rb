class CreateAgentTools < ActiveRecord::Migration[7.2]
  def change
    create_table :agent_tools do |t|
      t.references :agent, null: false, foreign_key: true
      t.references :tool_definition, null: false, foreign_key: true
      t.boolean :enabled, default: true, null: false
      t.boolean :requires_approval, default: false, null: false
      t.jsonb :config, default: {}
      t.integer :position, default: 0
      t.timestamps
    end

    add_index :agent_tools, [:agent_id, :tool_definition_id], unique: true, name: "idx_agent_tools_unique"
  end
end
