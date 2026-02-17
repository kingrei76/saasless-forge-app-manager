class CreateAgentExecutions < ActiveRecord::Migration[7.2]
  def change
    create_table :agent_executions do |t|
      t.references :agent, null: false, foreign_key: true
      t.references :parent_execution, foreign_key: { to_table: :agent_executions }
      t.references :trigger, foreign_key: { to_table: :agent_triggers }
      t.string :status, default: "pending", null: false
      t.string :mode, default: "test", null: false
      t.jsonb :state, default: {}
      t.jsonb :input_data, default: {}
      t.jsonb :output_data, default: {}
      t.text :error_message
      t.jsonb :error_details, default: {}
      t.datetime :started_at
      t.datetime :completed_at
      t.integer :total_tokens, default: 0
      t.decimal :total_cost, precision: 10, scale: 6, default: 0
      t.integer :iteration_count, default: 0
      t.timestamps
    end

    add_index :agent_executions, :status
    add_index :agent_executions, :mode
    add_index :agent_executions, [:agent_id, :status]
    add_index :agent_executions, [:agent_id, :created_at]
  end
end
