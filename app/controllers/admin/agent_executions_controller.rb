class Admin::AgentExecutionsController < Admin::BaseController
  before_action :set_execution, only: [:show, :approve_step, :reject_step, :cancel, :retry]

  def index
    @executions = AgentExecution.includes(:agent).recent
    @executions = @executions.by_status(params[:status]) if params[:status].present?
    @executions = @executions.where(agent_id: params[:agent_id]) if params[:agent_id].present?
    @executions = @executions.where(mode: params[:mode]) if params[:mode].present?
    @executions = @executions.limit(50)
  end

  def show
    @steps = @execution.steps.includes(:tool_definition, :target_agent).ordered
    @alerts = @execution.agent_alerts.recent
  end

  def approve_step
    step = @execution.steps.find(params[:step_id])
    step.update!(status: "approved")
    @execution.update!(status: "running")

    LanggraphClient.new.approve_step(@execution.id, step.step_number)
    redirect_to admin_agent_execution_path(@execution), notice: "Step approved."
  rescue => e
    redirect_to admin_agent_execution_path(@execution), alert: "Approval failed: #{e.message}"
  end

  def reject_step
    step = @execution.steps.find(params[:step_id])
    step.update!(status: "rejected")
    @execution.update!(status: "failed", error_message: "Step #{step.step_number} rejected by user")

    LanggraphClient.new.reject_step(@execution.id, step.step_number)
    redirect_to admin_agent_execution_path(@execution), notice: "Step rejected."
  rescue => e
    redirect_to admin_agent_execution_path(@execution), alert: "Rejection failed: #{e.message}"
  end

  def cancel
    @execution.update!(status: "cancelled", completed_at: Time.current)
    LanggraphClient.new.stop_execution(@execution.id)
    redirect_to admin_agent_execution_path(@execution), notice: "Execution cancelled."
  rescue => e
    redirect_to admin_agent_execution_path(@execution), alert: "Cancel failed: #{e.message}"
  end

  def retry
    new_execution = AgentExecution.create!(
      agent: @execution.agent,
      status: "pending",
      mode: @execution.mode,
      input_data: @execution.input_data
    )
    AgentExecutionJob.perform_later(new_execution.id)
    redirect_to admin_agent_execution_path(new_execution), notice: "Execution retried."
  end

  private

  def set_execution
    @execution = AgentExecution.find(params[:id])
  end
end
