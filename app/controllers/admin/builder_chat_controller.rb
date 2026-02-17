class Admin::BuilderChatController < Admin::BaseController
  before_action :load_builder_agent
  before_action :load_chat_session, only: [:send_message, :poll, :approve, :reject, :clear]

  def show
    agent_id = params[:agent_id]
    @agent = Agent.find(agent_id) if agent_id.present?
    @chat_session = find_or_create_session
    @messages = @chat_session&.messages_for_display || []
    @current_execution = @chat_session&.current_execution
  end

  def session
    agent_id = params[:agent_id]
    @agent = Agent.find(agent_id) if agent_id.present?
    @chat_session = find_or_create_session
    messages = @chat_session&.messages_for_display || []
    agent_name = @agent&.name || "a new agent"

    render json: {
      agent_id: @agent&.id,
      agent_name: agent_name,
      messages_html: render_to_string(partial: "admin/builder_chat/messages_list", locals: { messages: messages, agent: @agent, agent_name: agent_name }),
      execution_id: @chat_session&.current_execution&.id
    }
  end

  def send_message
    message = params[:message].to_s.strip
    if message.blank?
      return render json: { error: "Message cannot be empty" }, status: :unprocessable_entity
    end

    unless @builder_agent
      return render json: { error: "Agent Builder not configured. Run: rake agents:seed_builder" }, status: :unprocessable_entity
    end

    # Append user message to session
    @chat_session.append_message(role: "user", content: message)

    # Create execution linked to chat session
    execution = AgentExecution.create!(
      agent: @builder_agent,
      builder_chat_session: @chat_session,
      status: "pending",
      mode: @builder_agent.mode,
      input_data: { message: message }
    )

    # Fire background job (fall back to inline if SolidQueue unavailable)
    begin
      BuilderChatExecutionJob.perform_later(execution.id, @chat_session.id)
    rescue SolidQueue::Job::EnqueueError, ActiveRecord::StatementInvalid
      # SolidQueue tables not set up; run inline
      BuilderChatExecutionJob.perform_now(execution.id, @chat_session.id)
    end

    render json: {
      status: "ok",
      execution_id: execution.id,
      session_id: @chat_session.id
    }
  end

  def poll
    execution_id = params[:execution_id]
    return render json: { error: "No execution_id" }, status: :bad_request unless execution_id.present?

    execution = AgentExecution.find_by(id: execution_id)
    return render json: { error: "Execution not found" }, status: :not_found unless execution

    result = { status: execution.status }

    case execution.status
    when "awaiting_approval"
      pending_step = execution.steps.where(status: "pending").order(:step_number).last
      if pending_step
        result[:pending_step] = {
          step_number: pending_step.step_number,
          execution_id: execution.id,
          tool_name: pending_step.tool_definition&.name || pending_step.step_type,
          description: pending_step.input_data&.dig("description") || "The agent wants to perform: #{pending_step.tool_definition&.name || 'an action'}",
          details: pending_step.input_data
        }
      end
    when "completed"
      response_text = execution.output_data&.dig("response") ||
                      execution.output_data&.dig("result") ||
                      execution.output_data&.dig("message")
      result[:response_text] = response_text
      # Check if the target agent was modified (look for builder tool steps)
      builder_tool_slugs = %w[create_agent update_agent attach_tool_to_agent detach_tool_from_agent add_trigger_to_agent add_goal_to_agent add_handoff_to_agent]
      result[:agent_modified] = execution.steps.joins(:tool_definition)
        .where(tool_definitions: { slug: builder_tool_slugs }, status: "completed").exists?
    when "failed"
      result[:error_message] = execution.error_message
    end

    render json: result
  end

  def approve
    execution = AgentExecution.find(params[:execution_id])
    step_number = params[:step_number].to_i

    client = LanggraphClient.new
    client.approve_step(execution.id, step_number)

    # Mark step as approved
    step = execution.steps.find_by(step_number: step_number, status: "pending")
    step&.update!(status: "approved")
    execution.update!(status: "running")

    render json: { status: "ok" }
  rescue LanggraphClient::ServiceError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def reject
    execution = AgentExecution.find(params[:execution_id])
    step_number = params[:step_number].to_i

    client = LanggraphClient.new
    client.reject_step(execution.id, step_number)

    # Mark step as rejected
    step = execution.steps.find_by(step_number: step_number, status: "pending")
    step&.update!(status: "rejected")
    execution.update!(status: "running")

    # Note the rejection in chat memory
    @chat_session.append_message(
      role: "system",
      content: "You rejected: #{step&.tool_definition&.name || 'the proposed action'}"
    )

    render json: { status: "ok" }
  rescue LanggraphClient::ServiceError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def clear
    if @chat_session
      @chat_session.archive!
    end

    # Create a fresh session
    new_session = find_or_create_session(force_new: true)
    agent_name = @agent&.name || "a new agent"

    welcome = if @agent&.persisted?
                "Chat cleared. How can I help you configure #{agent_name}?"
              else
                "Chat cleared. What kind of agent would you like to build?"
              end

    render json: { status: "ok", welcome_message: welcome, session_id: new_session.id }
  end

  private

  def load_builder_agent
    @builder_agent = Agent.find_by(slug: "agent-builder")
  end

  def load_chat_session
    agent_id = params[:agent_id]
    @agent = Agent.find(agent_id) if agent_id.present?
    @chat_session = find_or_create_session
  end

  def find_or_create_session(force_new: false)
    return nil unless @builder_agent

    unless force_new
      existing = BuilderChatSession.active
        .where(user: current_user, agent: @agent, builder_agent: @builder_agent)
        .order(updated_at: :desc)
        .first
      return existing if existing
    end

    BuilderChatSession.create!(
      user: current_user,
      agent: @agent,
      builder_agent: @builder_agent,
      status: "active"
    )
  end
end
