class Admin::DashboardController < Admin::BaseController
  def index
    @user_count = User.count
    @app_count = App.count rescue 0
    @app_type_counts = App.group(:app_type).count rescue {}
    @client_count = Client.count rescue 0
    @monthly_cost = CostEntry.where("period_start >= ?", Date.current.beginning_of_month).sum(:amount) rescue 0
    @monthly_revenue = InvoiceLineItem.joins(:invoice)
      .where("invoices.period_start >= ?", Date.current.beginning_of_month)
      .sum(:amount) rescue 0

    # AI Agent stats
    @agent_count = Agent.active.count rescue 0
    @agent_executions_today = AgentExecution.today.count rescue 0
    @agent_open_alerts = AgentAlert.open_alerts.count rescue 0
  end
end
