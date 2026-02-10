class Admin::CostEntriesController < Admin::BaseController
  before_action :require_admin!
  before_action :set_cost_entry, only: [:show, :edit, :update, :destroy]
  before_action :set_clients, only: [:index]

  def index
    # Client filter
    @selected_client = params[:client_id].present? ? Client.find_by(id: params[:client_id]) : nil
    @clients_for_select = Client.order(:name)

    if @selected_client
      # Get billing period from client's Stripe subscription
      @billing_period_start, @billing_period_end = @selected_client.current_billing_period
      @days_into_cycle = @selected_client.days_into_billing_cycle
      @days_in_cycle = @selected_client.days_in_current_billing_cycle
      @cycle_progress = @selected_client.billing_cycle_progress_percentage

      # Get calculated costs grouped by app for this client
      @costs_by_app = CalculatedCost
        .for_client(@selected_client.id)
        .in_period(@billing_period_start, @billing_period_end)
        .includes(:app)
        .group_by(&:app)

      # Calculate totals
      @total_current = @costs_by_app.values.flatten.sum(&:total_cost)
      @total_projected = @costs_by_app.values.flatten.sum(&:projected_monthly_cost)

      # Manual entries for this client's apps
      app_ids = @selected_client.app_ids
      @manual_entries = CostEntry.manual_entries
        .where(app_id: app_ids)
        .where("period_start >= ? AND period_end <= ?", @billing_period_start, @billing_period_end)
        .includes(:app)
        .order(period_start: :desc)

      # API usage costs for this client's apps
      @api_costs_by_app = ApiUsageLog
        .where(app_id: app_ids)
        .where("created_at >= ? AND created_at <= ?", @billing_period_start, @billing_period_end.end_of_day)
        .group(:app_id)
        .select("app_id, COUNT(*) as call_count, SUM(estimated_cost) as total_cost")
        .index_by(&:app_id)
      @api_total_cost = @api_costs_by_app.values.sum { |r| r.total_cost.to_f }

      # Build unified costs structure
      build_unified_costs(app_ids)
    else
      # Show all cost entries when no client selected (legacy view)
      @billing_period_start = Date.current.beginning_of_month
      @billing_period_end = Date.current.end_of_month
      @days_into_cycle = Date.current.day
      @days_in_cycle = Date.current.end_of_month.day
      @cycle_progress = (@days_into_cycle.to_f / @days_in_cycle * 100).round(1)

      # Get all calculated costs grouped by app
      @costs_by_app = CalculatedCost
        .in_period(@billing_period_start, @billing_period_end)
        .includes(:app, :client)
        .group_by(&:app)

      @total_current = @costs_by_app.values.flatten.sum(&:total_cost)
      @total_projected = @costs_by_app.values.flatten.sum(&:projected_monthly_cost)

      # All manual entries for the period
      @manual_entries = CostEntry.manual_entries
        .where("period_start >= ? AND period_end <= ?", @billing_period_start, @billing_period_end)
        .includes(:app)
        .order(period_start: :desc)

      # API usage costs for all apps
      @api_costs_by_app = ApiUsageLog
        .where("created_at >= ? AND created_at <= ?", @billing_period_start, @billing_period_end.end_of_day)
        .group(:app_id)
        .select("app_id, COUNT(*) as call_count, SUM(estimated_cost) as total_cost")
        .index_by(&:app_id)
      @api_total_cost = @api_costs_by_app.values.sum { |r| r.total_cost.to_f }

      # Build unified costs structure
      build_unified_costs
    end

    # Legacy: keep @cost_entries for backward compatibility
    @cost_entries = CostEntry.includes(:app).order(period_start: :desc)
    @cost_entries = @cost_entries.where(app_id: params[:app_id]) if params[:app_id].present?
  end

  def sync_render
    results = { metadata: {}, costs: {} }

    # Sync app metadata from Render
    results[:metadata] = RenderSyncService.new.sync_app_metadata

    # Calculate costs for all clients
    results[:costs] = RenderCostCalculator.new.calculate_all_clients

    messages = []
    messages << "#{results[:metadata][:updated]} apps updated with Render metadata" if results[:metadata][:updated].to_i > 0
    messages << "#{results[:costs][:calculated]} cost calculations created/updated" if results[:costs][:calculated].to_i > 0

    notice = "Render sync complete. #{messages.join(', ')}."
    if results[:metadata][:unmatched]&.any?
      notice += " Unmatched services: #{results[:metadata][:unmatched].join(', ')}."
    end

    redirect_to admin_cost_entries_path(client_id: params[:client_id]), notice: notice
  rescue => e
    redirect_to admin_cost_entries_path(client_id: params[:client_id]), alert: "Sync failed: #{e.message}"
  end

  def show; end

  def new
    @cost_entry = CostEntry.new(app_id: params[:app_id])
    @apps = App.included.order(:name)
  end

  def create
    @cost_entry = CostEntry.new(cost_entry_params)

    if @cost_entry.save
      redirect_to admin_cost_entries_path, notice: "Cost entry created."
    else
      @apps = App.included.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @apps = App.included.order(:name)
  end

  def update
    if @cost_entry.update(cost_entry_params)
      redirect_to admin_cost_entries_path, notice: "Cost entry updated."
    else
      @apps = App.included.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @cost_entry.destroy
    redirect_to admin_cost_entries_path, notice: "Cost entry deleted."
  end

  private

  def set_cost_entry
    @cost_entry = CostEntry.find(params[:id])
  end

  def set_clients
    @clients = Client.order(:name)
  end

  def cost_entry_params
    params.require(:cost_entry).permit(:app_id, :service_name, :amount, :currency, :period_start, :period_end, :notes)
  end

  def build_unified_costs(app_ids = nil)
    # Combine infrastructure costs and API costs into a unified structure
    @unified_costs = {}

    # Add infrastructure costs
    @costs_by_app.each do |app, costs|
      next unless app
      @unified_costs[app.id] ||= { app: app, infra_cost: 0, infra_projected: 0, api_cost: 0, api_calls: 0, services: [], clients: [] }
      @unified_costs[app.id][:infra_cost] = costs.sum(&:total_cost)
      @unified_costs[app.id][:infra_projected] = costs.sum(&:projected_monthly_cost)
      @unified_costs[app.id][:services] = costs
      @unified_costs[app.id][:days_active] = costs.first&.days_active || 0
      @unified_costs[app.id][:days_in_period] = costs.first&.days_in_period || 30
      @unified_costs[app.id][:clients] = costs.map { |c| c.client&.name }.compact.uniq
    end

    # Add API costs
    @api_costs_by_app.each do |app_id, data|
      app = App.includes(:clients).find_by(id: app_id)
      next unless app
      @unified_costs[app_id] ||= { app: app, infra_cost: 0, infra_projected: 0, api_cost: 0, api_calls: 0, services: [], days_active: @days_into_cycle, days_in_period: @days_in_cycle, clients: [] }
      @unified_costs[app_id][:api_cost] = data.total_cost.to_f
      @unified_costs[app_id][:api_calls] = data.call_count.to_i
      # Add clients from app assignments if not already set from infrastructure costs
      @unified_costs[app_id][:clients] = app.clients.pluck(:name) if @unified_costs[app_id][:clients].blank?
    end

    # Calculate combined totals
    @unified_costs.each do |app_id, data|
      data[:total_cost] = data[:infra_cost] + data[:api_cost]
      # Project API costs for full month
      if @days_into_cycle > 0
        data[:api_projected] = (data[:api_cost] / @days_into_cycle) * @days_in_cycle
      else
        data[:api_projected] = 0
      end
      data[:total_projected] = data[:infra_projected] + data[:api_projected]
    end

    @grand_total_current = @total_current + @api_total_cost
    @grand_total_projected = @total_projected + @unified_costs.values.sum { |d| d[:api_projected] }
  end
end
