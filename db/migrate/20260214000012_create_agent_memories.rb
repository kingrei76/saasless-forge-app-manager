class CreateAgentMemories < ActiveRecord::Migration[7.2]
  def change
    create_table :agent_memories do |t|
      t.references :agent, null: false, foreign_key: true
      t.string :memory_type, default: "fact", null: false
      t.string :key
      t.text :content, null: false
      t.jsonb :embedding, default: {}
      t.decimal :relevance_score, precision: 5, scale: 4
      t.jsonb :metadata, default: {}
      t.datetime :expires_at
      t.timestamps
    end

    add_index :agent_memories, [:agent_id, :memory_type]
    add_index :agent_memories, [:agent_id, :key], unique: true, where: "key IS NOT NULL", name: "idx_agent_memories_key_unique"
    add_index :agent_memories, :expires_at
  end
end
