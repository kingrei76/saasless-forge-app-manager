class CreateBuilderChatSessions < ActiveRecord::Migration[7.2]
  def change
    create_table :builder_chat_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :agent, foreign_key: true, null: true
      t.references :builder_agent, foreign_key: { to_table: :agents }, null: false
      t.jsonb :conversation_memory, default: []
      t.jsonb :context, default: {}
      t.string :status, default: "active", null: false
      t.datetime :last_message_at
      t.timestamps
    end

    add_index :builder_chat_sessions, [:user_id, :agent_id],
              where: "status = 'active'",
              unique: true,
              name: "idx_builder_chat_active_user_agent"
  end
end
