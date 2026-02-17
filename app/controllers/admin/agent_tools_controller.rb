class Admin::AgentToolsController < Admin::BaseController
  before_action :set_agent
  before_action :set_agent_tool, only: [:update, :destroy, :toggle]

  def create
    @agent_tool = @agent.agent_tools.build(agent_tool_params)

    if @agent_tool.save
      redirect_to admin_agent_path(@agent, anchor: "tools"), notice: "Tool added."
    else
      redirect_to admin_agent_path(@agent, anchor: "tools"), alert: "Failed to add tool: #{@agent_tool.errors.full_messages.join(', ')}"
    end
  end

  def update
    if @agent_tool.update(agent_tool_params)
      redirect_to admin_agent_path(@agent, anchor: "tools"), notice: "Tool updated."
    else
      redirect_to admin_agent_path(@agent, anchor: "tools"), alert: "Failed to update tool."
    end
  end

  def destroy
    @agent_tool.destroy
    redirect_to admin_agent_path(@agent, anchor: "tools"), notice: "Tool removed."
  end

  def toggle
    @agent_tool.update!(enabled: !@agent_tool.enabled)
    redirect_to admin_agent_path(@agent, anchor: "tools"), notice: "Tool #{@agent_tool.enabled? ? 'enabled' : 'disabled'}."
  end

  private

  def set_agent
    @agent = Agent.find(params[:agent_id])
  end

  def set_agent_tool
    @agent_tool = @agent.agent_tools.find(params[:id])
  end

  def agent_tool_params
    params.require(:agent_tool).permit(:tool_definition_id, :enabled, :requires_approval, :position)
  end
end
