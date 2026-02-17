class Admin::AgentHandoffsController < Admin::BaseController
  before_action :set_agent
  before_action :set_handoff, only: [:update, :destroy]

  def create
    @handoff = @agent.agent_handoffs.build(handoff_params)

    if @handoff.save
      redirect_to admin_agent_path(@agent, anchor: "handoffs"), notice: "Handoff added."
    else
      redirect_to admin_agent_path(@agent, anchor: "handoffs"), alert: "Failed to add handoff: #{@handoff.errors.full_messages.join(', ')}"
    end
  end

  def update
    if @handoff.update(handoff_params)
      redirect_to admin_agent_path(@agent, anchor: "handoffs"), notice: "Handoff updated."
    else
      redirect_to admin_agent_path(@agent, anchor: "handoffs"), alert: "Failed to update handoff."
    end
  end

  def destroy
    @handoff.destroy
    redirect_to admin_agent_path(@agent, anchor: "handoffs"), notice: "Handoff removed."
  end

  private

  def set_agent
    @agent = Agent.find(params[:agent_id])
  end

  def set_handoff
    @handoff = @agent.agent_handoffs.find(params[:id])
  end

  def handoff_params
    params.require(:agent_handoff).permit(:target_agent_id, :name, :description, :priority, :enabled)
  end
end
