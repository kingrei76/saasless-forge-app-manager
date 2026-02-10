class Admin::DashboardController < Admin::BaseController
  def index
    @user_count = User.count
    @app_count = App.count rescue 0
    @client_count = Client.count rescue 0
    @monthly_cost = CostEntry.where("period_start >= ?", Date.current.beginning_of_month).sum(:amount) rescue 0
    @monthly_revenue = InvoiceLineItem.joins(:invoice)
      .where("invoices.period_start >= ?", Date.current.beginning_of_month)
      .sum(:amount) rescue 0
  end
end
