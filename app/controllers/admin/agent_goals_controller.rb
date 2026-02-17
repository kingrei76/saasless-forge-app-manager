class Admin::AgentGoalsController < Admin::BaseController
  before_action :set_agent
  before_action :set_goal, only: [:update, :destroy]

  def create
    @goal = @agent.agent_goals.build(goal_params)

    if @goal.save
      redirect_to admin_agent_path(@agent, anchor: "goals"), notice: "Goal added."
    else
      redirect_to admin_agent_path(@agent, anchor: "goals"), alert: "Failed to add goal: #{@goal.errors.full_messages.join(', ')}"
    end
  end

  def update
    if @goal.update(goal_params)
      redirect_to admin_agent_path(@agent, anchor: "goals"), notice: "Goal updated."
    else
      redirect_to admin_agent_path(@agent, anchor: "goals"), alert: "Failed to update goal."
    end
  end

  def destroy
    @goal.destroy
    redirect_to admin_agent_path(@agent, anchor: "goals"), notice: "Goal removed."
  end

  private

  def set_agent
    @agent = Agent.find(params[:agent_id])
  end

  def set_goal
    @goal = @agent.agent_goals.find(params[:id])
  end

  def goal_params
    params.require(:agent_goal).permit(:title, :description, :success_criteria, :priority, :status)
  end
end
