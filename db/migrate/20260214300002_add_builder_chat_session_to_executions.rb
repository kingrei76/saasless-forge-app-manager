class AddBuilderChatSessionToExecutions < ActiveRecord::Migration[7.2]
  def change
    add_reference :agent_executions, :builder_chat_session, foreign_key: true, null: true
  end
end
