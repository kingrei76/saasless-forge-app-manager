class EnhanceAgentTriggers < ActiveRecord::Migration[7.2]
  def change
    add_reference :agent_triggers, :tool_definition, foreign_key: true, null: true
    add_column :agent_triggers, :check_interval_minutes, :integer, default: 60
    add_column :agent_triggers, :last_checked_at, :datetime
    add_column :agent_triggers, :last_fired_at, :datetime
    add_column :agent_triggers, :cooldown_minutes, :integer, default: 0
    add_column :agent_triggers, :webhook_token, :string
    add_column :agent_triggers, :description, :text
    add_column :agent_triggers, :input_data_template, :jsonb, default: {}

    add_index :agent_triggers, :webhook_token, unique: true
  end
end
