class Admin::DashboardController < Admin::BaseController
  def index
    @user_count = User.count
    @app_count = App.count rescue 0
    @app_type_counts = App.group(:app_type).count rescue {}
    @client_count = Client.count rescue 0

    @selected_month = parse_month(params[:month])
    month_range = @selected_month.beginning_of_month..@selected_month.end_of_month
    @prev_month = @selected_month.prev_month
    @next_month = @selected_month.next_month
    @current_month = Date.current.beginning_of_month

    @monthly_cost = CostEntry.where(period_start: month_range).sum(:amount) rescue 0
    @monthly_revenue = InvoiceLineItem.joins(:invoice)
      .where(invoices: { period_start: month_range })
      .sum(:amount) rescue 0

    # AI Agent stats
    @agent_count = Agent.active.count rescue 0
    @agent_executions_today = AgentExecution.today.count rescue 0
    @agent_open_alerts = AgentAlert.open_alerts.count rescue 0
  end

  private

  def parse_month(value)
    Date.parse("#{value}-01").beginning_of_month
  rescue ArgumentError, TypeError
    Date.current.beginning_of_month
  end
end
