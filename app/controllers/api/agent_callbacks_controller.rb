class Api::AgentCallbacksController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  skip_before_action :authenticate_user_from_token!
  before_action :authenticate_service!

  def step_completed
    execution = AgentExecution.find(params[:execution_id])

    # LangGraph sends a nested "step" object; extract fields from it
    step_data = params[:step] || {}
    step_number = step_data[:step_number] || params[:step_number]
    node_name = step_data[:node_name] || params[:node_name] || ""
    step_type = map_node_to_step_type(node_name, step_data)
    duration_ms = step_data[:duration_ms] || params[:duration_ms]
    input_data = step_data[:input_data] || params[:input_data] || {}
    output_data = step_data[:output_data] || params[:output_data] || {}
    tool_calls = step_data[:tool_calls] || []

    # Try to find tool from tool_calls
    tool_name = tool_calls.first&.dig("name") || tool_calls.first&.dig(:name) || params[:tool_name]
    tool_def = ToolDefinition.find_by(slug: tool_name) if tool_name.present?

    step = execution.steps.create!(
      step_number: step_number,
      step_type: step_type,
      tool_definition: tool_def,
      input_data: safe_hash(input_data),
      output_data: safe_hash(output_data),
      status: "completed",
      duration_ms: duration_ms,
      tokens_used: params[:tokens_used] || 0,
      cost: params[:cost] || 0,
      started_at: step_data[:started_at] || params[:started_at] || Time.current,
      completed_at: Time.current
    )

    execution.update!(
      iteration_count: execution.steps.count,
      total_tokens: execution.steps.sum(:tokens_used),
      total_cost: execution.steps.sum(:cost)
    )

    render json: { status: "ok", step_id: step.id }
  end

  def approval_needed
    execution = AgentExecution.find(params[:execution_id])

    step_data = params[:step] || {}
    step_number = step_data[:step_number] || params[:step_number]
    tool_name = params[:tool_name] || step_data.dig(:tool_calls, 0, :name)
    tool_input = params[:tool_input] || step_data[:input_data] || {}

    step = execution.steps.create!(
      step_number: step_number,
      step_type: "approval_request",
      tool_definition: ToolDefinition.find_by(slug: tool_name),
      input_data: safe_hash(tool_input),
      status: "pending",
      started_at: Time.current
    )

    execution.update!(status: "awaiting_approval")

    AgentAlert.create!(
      agent: execution.agent,
      agent_execution: execution,
      agent_execution_step: step,
      alert_type: "approval_needed",
      severity: "warning",
      title: "Approval needed: #{tool_name || 'action'}",
      description: "Execution ##{execution.id} step #{step_number} requires human approval."
    )

    # If this execution belongs to a builder chat session, note the approval request
    if execution.builder_chat_session.present?
      description = tool_input.is_a?(Hash) ? (tool_input["description"] || tool_input[:description]) : nil
      description ||= "The agent wants to perform: #{tool_name || 'an action'}"
      execution.builder_chat_session.append_message(
        role: "system",
        content: "Approval needed: #{description}",
        metadata: { type: "approval_needed", step_number: step_number, tool_name: tool_name }
      )
    end

    render json: { status: "ok", step_id: step.id }
  end

  def execution_done
    execution = AgentExecution.find(params[:execution_id])

    # LangGraph sends result (not output_data)
    result = params[:result] || params[:output_data] || {}

    execution.update!(
      status: params[:status] || "completed",
      output_data: safe_hash(result),
      completed_at: Time.current,
      total_tokens: params[:total_tokens] || execution.total_tokens,
      total_cost: params[:total_cost] || execution.total_cost
    )

    # Save memories returned by the agent
    if params[:memories].present?
      params[:memories].each do |mem|
        execution.agent.agent_memories.create(
          memory_type: mem[:type] || "fact",
          key: mem[:key],
          content: mem[:content]
        )
      end
    end

    # Handoff chain: if execution returned a handoff_to agent, create child execution
    if params[:handoff_to].present?
      target = Agent.find_by(slug: params[:handoff_to])
      if target&.status == "active"
        child = AgentExecution.create!(
          agent: target,
          parent_execution: execution,
          status: "pending",
          mode: target.mode,
          input_data: params[:handoff_data] || execution.output_data || {}
        )
        AgentExecutionJob.perform_later(child.id)
      end
    end

    # Fire dependency triggers for agents that depend on this one
    AgentTriggerService.fire_dependency(execution.agent, execution)

    # If this execution belongs to a builder chat session, append the response
    if execution.builder_chat_session.present?
      # LangGraph sends result.response; also check output_data for compatibility
      response_text = result["response"].presence ||
                      result[:response].presence ||
                      result.values_at("result", "message").compact.first
      if response_text.present?
        execution.builder_chat_session.append_message(role: "assistant", content: response_text)
      end
    end

    # Fire event trigger for agent execution completion
    fire_execution_event!("agent.execution.completed", execution)

    render json: { status: "ok" }
  end

  def error
    execution = AgentExecution.find(params[:execution_id])
    execution.update!(
      status: "failed",
      error_message: params[:error] || params[:error_message],
      error_details: params[:error_details] || {},
      completed_at: Time.current
    )

    AgentAlert.create!(
      agent: execution.agent,
      agent_execution: execution,
      alert_type: "error",
      severity: params[:severity] || "error",
      title: "Execution failed: #{execution.agent.name}",
      description: params[:error] || params[:error_message]
    )

    # If this execution belongs to a builder chat session, note the error
    if execution.builder_chat_session.present?
      execution.builder_chat_session.append_message(
        role: "system",
        content: "Error: #{params[:error] || params[:error_message] || 'Execution failed'}"
      )
    end

    # Fire event trigger for agent execution failure
    fire_execution_event!("agent.execution.failed", execution)

    render json: { status: "ok" }
  end

  private

  def safe_hash(obj)
    return obj.to_unsafe_h.to_h if obj.respond_to?(:to_unsafe_h)
    return obj.to_h if obj.respond_to?(:to_h)
    {}
  end

  # Map LangGraph node names to our step_type enum
  def map_node_to_step_type(node_name, step_data = {})
    case node_name.to_s
    when "agent", "llm"
      "llm_call"
    when "tool_node", "tools"
      "tool_call"
    when "approval_check"
      "approval_request"
    when "decision", "router"
      "decision"
    when "handoff"
      "handoff"
    else
      # Infer from step data
      if step_data[:tool_calls].present? && step_data[:tool_calls].any?
        "tool_call"
      else
        "llm_call"
      end
    end
  end

  def fire_execution_event!(event_name, execution)
    event_data = {
      execution_id: execution.id,
      agent_id: execution.agent_id,
      agent_slug: execution.agent.slug,
      status: execution.status,
      error_message: execution.error_message,
      total_tokens: execution.total_tokens,
      total_cost: execution.total_cost
    }.compact
    AgentTriggerService.fire_event(event_name, event_data)
  rescue => e
    Rails.logger.error("AgentCallbacksController: Failed to fire #{event_name}: #{e.message}")
  end

  def authenticate_service!
    expected_token = Setting[:langgraph_auth_token] || ENV["LANGGRAPH_AUTH_TOKEN"]
    return if expected_token.blank? # Skip auth if no token configured

    provided_token = request.headers["Authorization"]&.remove("Bearer ")
    unless ActiveSupport::SecurityUtils.secure_compare(provided_token.to_s, expected_token.to_s)
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end
end
