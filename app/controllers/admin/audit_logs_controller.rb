class Admin::AuditLogsController < Admin::BaseController
  before_action :require_admin!

  def index
    @audit_logs = AuditLog.includes(:user).recent
    @audit_logs = @audit_logs.where(action: params[:action_filter]) if params[:action_filter].present?
    @audit_logs = @audit_logs.page(params[:page]) if @audit_logs.respond_to?(:page)
  end

  def show
    @audit_log = AuditLog.find(params[:id])
  end
end
