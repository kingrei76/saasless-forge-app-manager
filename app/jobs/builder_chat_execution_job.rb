class BuilderChatExecutionJob < ApplicationJob
  queue_as :default

  def perform(execution_id, chat_session_id)
    execution = AgentExecution.find(execution_id)
    chat_session = BuilderChatSession.find(chat_session_id)
    builder_agent = chat_session.builder_agent

    return if execution.status.in?(%w[cancelled completed failed])

    execution.update!(status: "running", started_at: Time.current)

    # Build augmented system prompt with target agent context
    system_prompt = builder_agent.system_prompt.to_s.dup
    if chat_session.agent.present?
      system_prompt << "\n\n## Current Context\n"
      system_prompt << "You are helping configure an existing agent:\n"
      system_prompt << "- Agent ID: #{chat_session.agent.id}\n"
      system_prompt << "- Name: #{chat_session.agent.name}\n"
      system_prompt << "- Slug: #{chat_session.agent.slug}\n"
      system_prompt << "- Status: #{chat_session.agent.status}\n"
      system_prompt << "- Category: #{chat_session.agent.category}\n"
      system_prompt << "When modifying this agent, use agent_id=#{chat_session.agent.id}.\n"
    else
      system_prompt << "\n\n## Current Context\n"
      system_prompt << "The user wants to create a new agent. Help them define the configuration step by step.\n"
    end

    # Get the last user message from conversation memory
    messages = chat_session.conversation_memory || []
    last_user_msg = messages.reverse.find { |m| m["role"] == "user" }
    message = last_user_msg&.dig("content") || ""

    # Build memory for LangGraph (full conversation history)
    memory = messages.map do |m|
      { role: m["role"], content: m["content"] }
    end

    context_data = {
      target_agent_id: chat_session.agent_id
    }

    client = LanggraphClient.new
    client.execute_chat(builder_agent, execution, message, memory, system_prompt, context_data)
  rescue LanggraphClient::ServiceError => e
    execution.update!(
      status: "failed",
      error_message: e.message,
      completed_at: Time.current
    )
    chat_session.append_message(
      role: "system",
      content: "Connection error: #{e.message}. The AI service may be temporarily unavailable."
    )
  rescue => e
    execution.update!(
      status: "failed",
      error_message: "Internal error: #{e.message}",
      completed_at: Time.current
    )
    chat_session.append_message(
      role: "system",
      content: "Something went wrong. Please try again."
    )
    raise
  end
end
