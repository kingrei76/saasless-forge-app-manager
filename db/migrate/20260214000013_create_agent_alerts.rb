class CreateAgentAlerts < ActiveRecord::Migration[7.2]
  def change
    create_table :agent_alerts do |t|
      t.references :agent, foreign_key: true
      t.references :agent_execution, foreign_key: true
      t.references :agent_execution_step, foreign_key: true
      t.string :alert_type, null: false
      t.string :severity, default: "info", null: false
      t.string :title, null: false
      t.text :description
      t.string :status, default: "open", null: false
      t.datetime :resolved_at
      t.references :resolved_by, foreign_key: { to_table: :users }
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :agent_alerts, :alert_type
    add_index :agent_alerts, :severity
    add_index :agent_alerts, :status
    add_index :agent_alerts, [:status, :severity]
  end
end
