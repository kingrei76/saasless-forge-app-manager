class Admin::AgentTriggersController < Admin::BaseController
  before_action :set_agent
  before_action :set_trigger, only: [:update, :destroy, :fire]

  def create
    @trigger = @agent.agent_triggers.build(trigger_params)
    parse_json_fields(@trigger)

    if @trigger.save
      redirect_to admin_agent_path(@agent, anchor: "triggers"), notice: "Trigger added."
    else
      redirect_to admin_agent_path(@agent, anchor: "triggers"), alert: "Failed to add trigger: #{@trigger.errors.full_messages.join(', ')}"
    end
  end

  def update
    @trigger.assign_attributes(trigger_params)
    parse_json_fields(@trigger)

    if @trigger.save
      redirect_to admin_agent_path(@agent, anchor: "triggers"), notice: "Trigger updated."
    else
      redirect_to admin_agent_path(@agent, anchor: "triggers"), alert: "Failed to update trigger."
    end
  end

  def destroy
    @trigger.destroy
    redirect_to admin_agent_path(@agent, anchor: "triggers"), notice: "Trigger removed."
  end

  def fire
    if @agent.status != "active"
      redirect_to admin_agent_path(@agent, anchor: "triggers"), alert: "Agent must be active to fire triggers."
      return
    end

    execution = @trigger.fire!
    if execution
      redirect_to admin_agent_execution_path(execution), notice: "Trigger fired. Execution started."
    else
      redirect_to admin_agent_path(@agent, anchor: "triggers"), alert: "Trigger is within cooldown period."
    end
  end

  private

  def set_agent
    @agent = Agent.find(params[:agent_id])
  end

  def set_trigger
    @trigger = @agent.agent_triggers.find(params[:id])
  end

  def trigger_params
    params.require(:agent_trigger).permit(
      :trigger_type, :event_name, :depends_on_agent_id, :schedule, :enabled,
      :tool_definition_id, :check_interval_minutes, :cooldown_minutes,
      :description, :input_data_template, :condition
    )
  end

  def parse_json_fields(trigger)
    if params[:agent_trigger][:condition].is_a?(String) && params[:agent_trigger][:condition].present?
      trigger.condition = JSON.parse(params[:agent_trigger][:condition]) rescue trigger.condition
    end
    if params[:agent_trigger][:input_data_template].is_a?(String) && params[:agent_trigger][:input_data_template].present?
      trigger.input_data_template = JSON.parse(params[:agent_trigger][:input_data_template]) rescue trigger.input_data_template
    end
  end
end
