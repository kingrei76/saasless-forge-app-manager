class Api::AgentConfigTriggersController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_agent

  def create
    trigger = @agent.agent_triggers.build(trigger_params)

    if trigger.save
      audit!("api_agent_trigger_created", @agent, { trigger_type: trigger.trigger_type, trigger_id: trigger.id })
      render json: {
        id: trigger.id,
        trigger_type: trigger.trigger_type,
        description: trigger.try(:description),
        event_name: trigger.try(:event_name),
        schedule: trigger.try(:schedule),
        enabled: trigger.enabled?,
        webhook_url: trigger.webhook_url
      }, status: :created
    else
      render json: { errors: trigger.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    trigger = @agent.agent_triggers.find(params[:id])
    trigger.destroy!

    audit!("api_agent_trigger_removed", @agent, { trigger_id: params[:id] })
    render json: { status: "ok" }
  end

  private

  def set_agent
    @agent = Agent.find(params[:agent_id])
  end

  def trigger_params
    permitted = params.require(:trigger).permit(
      :trigger_type, :description, :event_name, :schedule,
      :tool_definition_id, :depends_on_agent_id, :enabled,
      :cooldown_minutes, :check_interval_minutes
    )

    # Parse condition and input_data_template from strings if needed
    if params[:trigger][:condition].is_a?(String) && params[:trigger][:condition].present?
      permitted[:condition] = JSON.parse(params[:trigger][:condition]) rescue params[:trigger][:condition]
    elsif params[:trigger][:condition].is_a?(Hash)
      permitted[:condition] = params[:trigger][:condition].to_unsafe_h
    end

    if params[:trigger][:input_data_template].is_a?(String) && params[:trigger][:input_data_template].present?
      permitted[:input_data_template] = JSON.parse(params[:trigger][:input_data_template]) rescue params[:trigger][:input_data_template]
    elsif params[:trigger][:input_data_template].is_a?(Hash)
      permitted[:input_data_template] = params[:trigger][:input_data_template].to_unsafe_h
    end

    permitted
  end

  def audit!(action, auditable, changes_data = {})
    return unless defined?(AuditLogger)
    AuditLogger.log(user: current_user, action: action, auditable: auditable, changes_data: changes_data)
  end
end
