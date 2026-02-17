class Api::AgentConfigToolsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_agent

  def create
    tool_def = ToolDefinition.find(params[:tool_definition_id])
    agent_tool = @agent.agent_tools.build(
      tool_definition: tool_def,
      enabled: params[:enabled] != false,
      requires_approval: params[:requires_approval] || false,
      position: params[:position] || @agent.agent_tools.count
    )

    if agent_tool.save
      audit!("api_agent_tool_added", @agent, { tool_definition_id: tool_def.id, tool_name: tool_def.name })
      render json: {
        id: agent_tool.id,
        tool_definition_id: tool_def.id,
        name: tool_def.name,
        slug: tool_def.slug,
        enabled: agent_tool.enabled?,
        requires_approval: agent_tool.try(:requires_approval)
      }, status: :created
    else
      render json: { errors: agent_tool.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    agent_tool = @agent.agent_tools.find(params[:id])
    tool_name = agent_tool.tool_definition.name
    agent_tool.destroy!

    audit!("api_agent_tool_removed", @agent, { tool_name: tool_name })
    render json: { status: "ok" }
  end

  private

  def set_agent
    @agent = Agent.find(params[:agent_id])
  end

  def audit!(action, auditable, changes_data = {})
    return unless defined?(AuditLogger)
    AuditLogger.log(user: current_user, action: action, auditable: auditable, changes_data: changes_data)
  end
end
