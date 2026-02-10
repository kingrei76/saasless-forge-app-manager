class Admin::CostsController < Admin::BaseController
  def index
    @monthly_costs = CostEntry
      .group("DATE_TRUNC('month', period_start)")
      .sum(:amount)
      .sort_by { |k, _| k }

    @per_app_costs = CostEntry
      .joins(:app)
      .group("apps.name")
      .sum(:amount)
      .sort_by { |_, v| -v }

    @per_service_costs = CostEntry
      .group(:service_name)
      .sum(:amount)
      .sort_by { |_, v| -v }
  end
end
