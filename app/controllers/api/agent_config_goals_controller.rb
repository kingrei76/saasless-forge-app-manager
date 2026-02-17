class Api::AgentConfigGoalsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_agent

  def create
    goal = @agent.agent_goals.build(goal_params)

    if goal.save
      audit!("api_agent_goal_created", @agent, { goal_title: goal.title, goal_id: goal.id })
      render json: {
        id: goal.id,
        title: goal.title,
        description: goal.try(:description),
        status: goal.status,
        priority: goal.try(:priority)
      }, status: :created
    else
      render json: { errors: goal.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    goal = @agent.agent_goals.find(params[:id])
    goal.destroy!

    audit!("api_agent_goal_removed", @agent, { goal_id: params[:id] })
    render json: { status: "ok" }
  end

  private

  def set_agent
    @agent = Agent.find(params[:agent_id])
  end

  def goal_params
    params.require(:goal).permit(:title, :description, :status, :priority, :success_criteria)
  end

  def audit!(action, auditable, changes_data = {})
    return unless defined?(AuditLogger)
    AuditLogger.log(user: current_user, action: action, auditable: auditable, changes_data: changes_data)
  end
end
