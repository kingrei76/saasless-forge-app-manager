class Admin::AgentAlertsController < Admin::BaseController
  before_action :set_alert, only: [:show, :update, :acknowledge, :resolve, :dismiss]

  def index
    @alerts = AgentAlert.includes(:agent, :agent_execution).recent
    @alerts = @alerts.where(status: params[:status]) if params[:status].present?
    @alerts = @alerts.by_severity(params[:severity]) if params[:severity].present?
    @alerts = @alerts.by_type(params[:alert_type]) if params[:alert_type].present?
    @alerts = @alerts.limit(50)

    @open_count = AgentAlert.open_alerts.count
    @unresolved_count = AgentAlert.unresolved.count
  end

  def show
  end

  def update
    if @alert.update(alert_params)
      redirect_to admin_agent_alerts_path, notice: "Alert updated."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def acknowledge
    @alert.acknowledge!(current_user)
    redirect_to admin_agent_alerts_path, notice: "Alert acknowledged."
  end

  def resolve
    @alert.resolve!(current_user)
    redirect_to admin_agent_alerts_path, notice: "Alert resolved."
  end

  def dismiss
    @alert.dismiss!(current_user)
    redirect_to admin_agent_alerts_path, notice: "Alert dismissed."
  end

  private

  def set_alert
    @alert = AgentAlert.find(params[:id])
  end

  def alert_params
    params.require(:agent_alert).permit(:status)
  end
end
