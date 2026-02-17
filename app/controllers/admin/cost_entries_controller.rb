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
      # Show all apps with their Render and API costs
      @billing_period_start = Date.current.beginning_of_month
      @billing_period_end = Date.current.end_of_month
      @days_into_cycle = Date.current.day
      @days_in_cycle = Date.current.end_of_month.day
      @cycle_progress = (@days_into_cycle.to_f / @days_in_cycle * 100).round(1)

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

      # Build unified costs from Render services and API usage
      build_unified_costs_from_services
    end

    # Legacy: keep @cost_entries for backward compatibility
    @cost_entries = CostEntry.includes(:app).order(period_start: :desc)
    @cost_entries = @cost_entries.where(app_id: params[:app_id]) if params[:app_id].present?
  end

  def sync_render
    github_accounts = GithubAccount.all
    render_accounts = GithubAccount.with_render
    errors = []
    github_synced = 0
    render_results = { updated: 0, matched: 0, unmatched: [], services_synced: 0 }

    # Sync GitHub repos from all accounts
    github_accounts.each do |account|
      result = GithubSyncService.new(account).sync!
      github_synced += result[:synced].to_i
    rescue StandardError => e
      errors << "GitHub #{account.display_name}: #{e.message}"
    end

    # Sync Render services and app metadata from all Render accounts
    render_accounts.each do |account|
      result = RenderSyncService.new(github_account: account).sync_app_metadata
      render_results[:updated] += result[:updated].to_i
      render_results[:services_synced] += result[:services_synced].to_i
      render_results[:unmatched].concat(result[:unmatched] || [])
      account.update!(render_last_synced_at: Time.current)
    rescue StandardError => e
      errors << "Render #{account.display_name}: #{e.message}"
    end

    # Calculate costs for all clients
    cost_results = RenderCostCalculator.new.calculate_all_clients

    messages = []
    messages << "#{github_synced} repos synced from #{github_accounts.count} GitHub account(s)" if github_synced > 0
    messages << "#{render_results[:services_synced]} Render services from #{render_accounts.count} account(s)" if render_results[:services_synced] > 0
    messages << "#{cost_results[:calculated]} cost calculations updated" if cost_results[:calculated].to_i > 0

    notice = "Sync complete. #{messages.join(', ')}."
    notice += " Unmatched: #{render_results[:unmatched].join(', ')}." if render_results[:unmatched].any?
    notice += " Errors: #{errors.join('; ')}" if errors.any?

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
      @unified_costs[app.id] ||= { app: app, infra_cost: 0, infra_projected: 0, api_cost: 0, api_calls: 0, services: [], render_services: [], clients: [] }
      @unified_costs[app.id][:infra_cost] = costs.sum(&:total_cost)
      @unified_costs[app.id][:infra_projected] = costs.sum(&:projected_monthly_cost)
      @unified_costs[app.id][:services] = costs
      @unified_costs[app.id][:render_services] = app.render_services.active
      @unified_costs[app.id][:days_active] = costs.first&.days_active || 0
      @unified_costs[app.id][:days_in_period] = costs.first&.days_in_period || 30
      @unified_costs[app.id][:clients] = costs.map { |c| c.client&.name }.compact.uniq
    end

    # Add API costs
    @api_costs_by_app.each do |app_id, data|
      app = App.includes(:clients).find_by(id: app_id)
      next unless app
      @unified_costs[app_id] ||= { app: app, infra_cost: 0, infra_projected: 0, api_cost: 0, api_calls: 0, services: [], render_services: [], days_active: @days_into_cycle, days_in_period: @days_in_cycle, clients: [] }
      @unified_costs[app_id][:api_cost] = data.total_cost.to_f
      @unified_costs[app_id][:api_calls] = data.call_count.to_i
      @unified_costs[app_id][:clients] = app.clients.pluck(:name) if @unified_costs[app_id][:clients].blank?
    end

    finalize_unified_costs
  end

  def build_unified_costs_from_services
    @unified_costs = {}

    # Include all apps that have Render services (regardless of client)
    App.includes(:render_services, :clients, :api_usage_logs).find_each do |app|
      render_services = app.render_services.active
      api_data = @api_costs_by_app[app.id]

      next if render_services.empty? && api_data.nil?

      infra_cost = render_services.sum(&:monthly_price)
      # Prorate based on days into the month
      prorated_infra = @days_into_cycle > 0 ? (infra_cost.to_f / @days_in_cycle) * @days_into_cycle : 0

      @unified_costs[app.id] = {
        app: app,
        infra_cost: prorated_infra.round(2),
        infra_projected: infra_cost.round(2),
        api_cost: api_data&.total_cost.to_f,
        api_calls: api_data&.call_count.to_i,
        render_services: render_services,
        days_active: @days_into_cycle,
        days_in_period: @days_in_cycle,
        clients: app.clients.pluck(:name)
      }
    end

    @total_current = @unified_costs.values.sum { |d| d[:infra_cost] }
    @total_projected = @unified_costs.values.sum { |d| d[:infra_projected] }

    finalize_unified_costs
  end

  def finalize_unified_costs
    @unified_costs.each do |app_id, data|
      data[:total_cost] = data[:infra_cost] + data[:api_cost]
      if @days_into_cycle > 0
        data[:api_projected] = (data[:api_cost] / @days_into_cycle) * @days_in_cycle
      else
        data[:api_projected] = 0
      end
      data[:total_projected] = (data[:infra_projected] || 0) + data[:api_projected]
    end

    @grand_total_current = (@total_current || 0) + @api_total_cost
    @grand_total_projected = (@total_projected || 0) + @unified_costs.values.sum { |d| d[:api_projected] }
  end
end
