class RenderCostCalculator
  # Plan prices - should be loaded from RenderPrice table
  # These are fallbacks
  SERVICE_PLAN_PRICES = {
    "free" => 0,
    "starter" => 7,
    "standard" => 25,
    "pro" => 85,
    "pro_plus" => 175,
    "pro_max" => 225,
    "pro_ultra" => 450
  }.freeze

  DATABASE_PLAN_PRICES = {
    "free" => 0,
    "basic_256mb" => 6,
    "basic_1gb" => 19,
    "basic_4gb" => 75,
    "pro_4gb" => 55,
    "pro_8gb" => 100,
    "pro_16gb" => 200,
    "pro_32gb" => 400
  }.freeze

  def calculate_all_clients
    results = { calculated: 0, clients_processed: 0, errors: [] }

    Client.find_each do |client|
      calculate_for_client(client, results)
      results[:clients_processed] += 1
    end

    results
  end

  def calculate_for_client(client, results = { calculated: 0, errors: [] })
    billing_start, billing_end = client.current_billing_period

    # Calculate costs for all apps with linked RenderServices
    client.apps.includes(:render_services, :cost_entries).find_each do |app|
      calculate_for_app(app, client, billing_start, billing_end, results)
    end

    results
  end

  def calculate_for_app(app, client, billing_start, billing_end, results = { calculated: 0, errors: [] })
    # Calculate costs for each linked RenderService
    app.render_services.active.each do |render_service|
      calculate_for_render_service(render_service, app, client, billing_start, billing_end, results)
    end

    # Legacy: also calculate for apps with render_service_id but no RenderService records
    if app.render_service_id.present? && app.render_services.empty?
      calculate_for_app_legacy(app, client, billing_start, billing_end, results)
    end

    results
  end

  def calculate_for_render_service(render_service, app, client, billing_start, billing_end, results)
    begin
      # Get the monthly price from RenderService
      monthly_price = render_service.monthly_price

      # Calculate proration
      days_in_period = (billing_end - billing_start).to_i + 1
      days_active = calculate_days_active_for_service(render_service, billing_start, billing_end)
      prorated_multiplier = days_active.to_f / days_in_period

      # Calculate costs
      base_cost = monthly_price * prorated_multiplier
      bandwidth_cost = calculate_bandwidth_cost(app, billing_start, billing_end)
      storage_cost = calculate_storage_cost(app, billing_start, billing_end)
      total_cost = base_cost + bandwidth_cost + storage_cost

      # Calculate projected monthly cost
      if days_active > 0
        daily_rate = total_cost / days_active
        projected_monthly = daily_rate * 30
      else
        projected_monthly = monthly_price
      end

      # Store the calculated cost
      calculated_cost = CalculatedCost.find_or_initialize_by(
        app_id: app.id,
        client_id: client.id,
        render_service_id: render_service.render_service_id,
        billing_period_start: billing_start
      )

      calculated_cost.assign_attributes(
        billing_period_end: billing_end,
        service_type: render_service.service_type,
        plan_name: render_service.plan,
        base_cost: base_cost.round(2),
        bandwidth_cost: bandwidth_cost.round(2),
        storage_cost: storage_cost.round(2),
        total_cost: total_cost.round(2),
        days_in_period: days_in_period,
        days_active: days_active,
        prorated_multiplier: prorated_multiplier.round(4),
        projected_monthly_cost: projected_monthly.round(2)
      )

      if calculated_cost.save
        results[:calculated] += 1
      end
    rescue => e
      results[:errors] << { app_id: app.id, client_id: client.id, render_service_id: render_service.id, error: e.message }
    end
  end

  # Legacy calculation for apps that have render_service_id but no RenderService records
  def calculate_for_app_legacy(app, client, billing_start, billing_end, results)
    begin
      # Get the monthly price for this service
      monthly_price = get_monthly_price(app)

      # Calculate proration
      days_in_period = (billing_end - billing_start).to_i + 1
      days_active = calculate_days_active(app, billing_start, billing_end)
      prorated_multiplier = days_active.to_f / days_in_period

      # Calculate costs
      base_cost = monthly_price * prorated_multiplier
      bandwidth_cost = calculate_bandwidth_cost(app, billing_start, billing_end)
      storage_cost = calculate_storage_cost(app, billing_start, billing_end)
      total_cost = base_cost + bandwidth_cost + storage_cost

      # Calculate projected monthly cost
      if days_active > 0
        daily_rate = total_cost / days_active
        projected_monthly = daily_rate * 30
      else
        projected_monthly = monthly_price
      end

      # Store the calculated cost
      calculated_cost = CalculatedCost.find_or_initialize_by(
        app_id: app.id,
        client_id: client.id,
        render_service_id: app.render_service_id,
        billing_period_start: billing_start
      )

      calculated_cost.assign_attributes(
        billing_period_end: billing_end,
        service_type: app.render_service_type,
        plan_name: app.render_plan,
        base_cost: base_cost.round(2),
        bandwidth_cost: bandwidth_cost.round(2),
        storage_cost: storage_cost.round(2),
        total_cost: total_cost.round(2),
        days_in_period: days_in_period,
        days_active: days_active,
        prorated_multiplier: prorated_multiplier.round(4),
        projected_monthly_cost: projected_monthly.round(2)
      )

      if calculated_cost.save
        results[:calculated] += 1
      end
    rescue => e
      results[:errors] << { app_id: app.id, client_id: client.id, error: e.message }
    end

    results
  end

  private

  def get_monthly_price(app)
    # First try to get from RenderPrice table
    price = RenderPrice.current_price(
      service_type: app.render_service_type || "web_service",
      plan_name: app.render_plan
    )

    return price if price > 0

    # Fallback to hardcoded prices
    plan = app.render_plan || "free"

    if app.render_service_type == "postgres"
      DATABASE_PLAN_PRICES[plan] || 0
    else
      SERVICE_PLAN_PRICES[plan] || 0
    end
  end

  def calculate_days_active(app, billing_start, billing_end)
    # If we know when the app was created on Render, use that
    if app.render_created_at.present?
      app_start = app.render_created_at.to_date
      active_start = [billing_start, app_start].max
      return 0 if active_start > billing_end
      (billing_end - active_start).to_i + 1
    else
      # Assume active for the full period
      (billing_end - billing_start).to_i + 1
    end
  end

  def calculate_days_active_for_service(render_service, billing_start, billing_end)
    # If we know when the service was created on Render, use that
    if render_service.render_created_at.present?
      service_start = render_service.render_created_at.to_date
      active_start = [billing_start, service_start].max
      return 0 if active_start > billing_end
      (billing_end - active_start).to_i + 1
    else
      # Assume active for the full period
      (billing_end - billing_start).to_i + 1
    end
  end

  def calculate_bandwidth_cost(app, billing_start, billing_end)
    # Get bandwidth usage from metrics
    total_gb = RenderUsageMetric.total_bandwidth_gb(
      app_id: app.id,
      start_time: billing_start.to_time,
      end_time: billing_end.to_time.end_of_day
    )

    # Most plans include 100GB of bandwidth
    included_gb = 100
    overage_gb = [total_gb - included_gb, 0].max
    overage_rate = 0.10 # $0.10 per GB

    overage_gb * overage_rate
  end

  def calculate_storage_cost(app, billing_start, billing_end)
    # For now, assume no storage overage
    # This would need to be enhanced to track actual storage usage
    0
  end
end
