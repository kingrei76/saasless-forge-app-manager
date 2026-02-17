class CreateAgentTriggers < ActiveRecord::Migration[7.2]
  def change
    create_table :agent_triggers do |t|
      t.references :agent, null: false, foreign_key: true
      t.string :trigger_type, null: false
      t.string :event_name
      t.references :depends_on_agent, foreign_key: { to_table: :agents }
      t.string :schedule
      t.jsonb :condition, default: {}
      t.boolean :enabled, default: true, null: false
      t.timestamps
    end

    add_index :agent_triggers, [:agent_id, :trigger_type]
    add_index :agent_triggers, :event_name
  end
end
