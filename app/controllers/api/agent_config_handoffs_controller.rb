class Api::AgentConfigHandoffsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_agent

  def create
    handoff = @agent.agent_handoffs.build(handoff_params)
    handoff.source_agent = @agent

    if handoff.save
      audit!("api_agent_handoff_created", @agent, {
        target_agent_id: handoff.target_agent_id,
        target_agent_name: handoff.target_agent.name
      })
      render json: {
        id: handoff.id,
        source_agent_id: handoff.source_agent_id,
        target_agent_id: handoff.target_agent_id,
        target_agent_name: handoff.target_agent.name,
        enabled: handoff.try(:enabled),
        priority: handoff.try(:priority),
        condition: handoff.try(:condition)
      }, status: :created
    else
      render json: { errors: handoff.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    handoff = @agent.agent_handoffs.find(params[:id])
    handoff.destroy!

    audit!("api_agent_handoff_removed", @agent, { handoff_id: params[:id] })
    render json: { status: "ok" }
  end

  private

  def set_agent
    @agent = Agent.find(params[:agent_id])
  end

  def handoff_params
    permitted = params.require(:handoff).permit(:target_agent_id, :enabled, :priority)

    if params[:handoff][:condition].is_a?(String) && params[:handoff][:condition].present?
      permitted[:condition] = JSON.parse(params[:handoff][:condition]) rescue params[:handoff][:condition]
    elsif params[:handoff][:condition].is_a?(Hash)
      permitted[:condition] = params[:handoff][:condition].to_unsafe_h
    end

    permitted
  end

  def audit!(action, auditable, changes_data = {})
    return unless defined?(AuditLogger)
    AuditLogger.log(user: current_user, action: action, auditable: auditable, changes_data: changes_data)
  end
end
