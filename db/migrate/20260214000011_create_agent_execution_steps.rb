class CreateAgentExecutionSteps < ActiveRecord::Migration[7.2]
  def change
    create_table :agent_execution_steps do |t|
      t.references :agent_execution, null: false, foreign_key: true
      t.integer :step_number, null: false
      t.string :step_type, null: false
      t.references :tool_definition, foreign_key: true
      t.references :target_agent, foreign_key: { to_table: :agents }
      t.jsonb :input_data, default: {}
      t.jsonb :output_data, default: {}
      t.string :status, default: "pending", null: false
      t.text :error_message
      t.integer :duration_ms
      t.integer :tokens_used, default: 0
      t.decimal :cost, precision: 10, scale: 6, default: 0
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    add_index :agent_execution_steps, [:agent_execution_id, :step_number], unique: true, name: "idx_execution_steps_unique"
    add_index :agent_execution_steps, :status
    add_index :agent_execution_steps, :step_type
  end
end
