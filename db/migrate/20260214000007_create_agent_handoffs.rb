class CreateAgentHandoffs < ActiveRecord::Migration[7.2]
  def change
    create_table :agent_handoffs do |t|
      t.references :source_agent, null: false, foreign_key: { to_table: :agents }
      t.references :target_agent, null: false, foreign_key: { to_table: :agents }
      t.string :name
      t.text :description
      t.jsonb :condition, default: {}
      t.integer :priority, default: 0
      t.boolean :enabled, default: true, null: false
      t.timestamps
    end

    add_index :agent_handoffs, [:source_agent_id, :target_agent_id], unique: true, name: "idx_agent_handoffs_unique"
  end
end
