class Admin::AgentDashboardController < Admin::BaseController
  def show
    service = AgentObservabilityService.new

    @stats = service.overview_stats
    @active_executions = service.active_executions
    @recent_alerts = service.recent_alerts(limit: 10)
    @executions_by_status = service.executions_by_status
    @executions_by_agent = service.executions_by_agent
    @daily_executions = service.daily_executions
    @cost_by_agent = service.cost_by_agent
    @cost_by_day = service.cost_by_day
    @tokens_by_day = service.tokens_by_day
    @tool_usage = service.tool_usage_stats
  end
end
