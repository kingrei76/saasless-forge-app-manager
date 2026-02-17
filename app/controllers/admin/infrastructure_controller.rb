class Admin::InfrastructureController < Admin::BaseController
  def show
    @tab = params[:tab] || "service_providers"
    @period = params[:period] || "this_month"

    load_service_providers_data
    load_render_services_data
    load_api_usage_data
    load_combined_stats
  end

  def assign_api_logs
    app = App.find(params[:app_id])
    count = ApiUsageLog.without_app.update_all(app_id: app.id)
    redirect_to admin_infrastructure_path(tab: "usage"),
                notice: "Assigned #{count} API usage logs to #{app.name}"
  end

  def sync_render
    github_accounts = GithubAccount.all
    render_accounts = GithubAccount.with_render
    errors = []
    github_synced = 0
    render_results = { services_synced: 0, services_created: 0, services_updated: 0 }

    # Sync GitHub repos from all accounts
    github_accounts.each do |account|
      result = GithubSyncService.new(account).sync!
      github_synced += result[:synced].to_i
    rescue StandardError => e
      errors << "GitHub #{account.display_name}: #{e.message}"
    end

    # Sync Render services from all Render accounts
    render_accounts.each do |account|
      result = RenderSyncService.new(github_account: account).sync_render_services
      account.update!(render_last_synced_at: Time.current)
      render_results[:services_synced] += result[:services_synced].to_i
      render_results[:services_created] += result[:services_created].to_i
      render_results[:services_updated] += result[:services_updated].to_i
    rescue StandardError => e
      errors << "Render #{account.display_name}: #{e.message}"
    end

    messages = []
    messages << "#{github_synced} repos from #{github_accounts.count} GitHub account(s)" if github_synced > 0
    messages << "#{render_results[:services_synced]} Render services from #{render_accounts.count} account(s)" if render_results[:services_synced] > 0

    notice = "Sync complete. #{messages.join(', ')}."
    notice += " Errors: #{errors.join('; ')}" if errors.any?

    redirect_to admin_infrastructure_path(tab: "render_services"), notice: notice
  rescue StandardError => e
    redirect_to admin_infrastructure_path(tab: "render_services"), alert: "Sync failed: #{e.message}"
  end

  private

  def load_service_providers_data
    @service_providers = ServiceProvider.order(:name)
    @service_provider_count = ServiceProvider.active.count
  end

  def load_render_services_data
    @render_services = RenderService.includes(:app, :render_workspace).order(:name)

    # Filters
    @render_services = @render_services.by_type(params[:service_type]) if params[:service_type].present?
    @render_services = @render_services.by_owner(params[:owner_id]) if params[:owner_id].present?

    if params[:linked] == "true"
      @render_services = @render_services.linked
    elsif params[:linked] == "false"
      @render_services = @render_services.unlinked
    end

    @apps = App.order(:name)
    @workspaces = RenderWorkspace.order(:name)
    @service_types = RenderService.distinct.pluck(:service_type).compact.sort

    # Render stats
    @render_total_services = RenderService.count
    @render_linked_count = RenderService.linked.count
    @render_unlinked_count = RenderService.unlinked.count
    @render_monthly_cost = RenderService.active.sum { |s| s.monthly_price }
  end

  def load_api_usage_data
    base_scope = ApiUsageLog.all

    @api_logs = case @period
    when "last_month"
      base_scope.last_month
    when "all_time"
      base_scope
    else # this_month
      base_scope.this_month
    end

    # Provider filter
    if params[:provider_id].present?
      @api_logs = @api_logs.where(service_provider_id: params[:provider_id])
    end

    # App filter
    if params[:app_id].present?
      @api_logs = @api_logs.where(app_id: params[:app_id])
    end

    @api_by_operation = @api_logs.by_operation.order("total_cost DESC NULLS LAST")
    @api_by_app = @api_logs.with_app.costs_by_app.order("total_cost DESC NULLS LAST")
    @api_total_cost = @api_logs.sum(:estimated_cost)
    @api_total_calls = @api_logs.count
    @api_total_tokens = @api_logs.sum("COALESCE(input_tokens, 0) + COALESCE(output_tokens, 0)")
    @api_input_tokens = @api_logs.sum(:input_tokens)
    @api_output_tokens = @api_logs.sum(:output_tokens)

    # For this month comparison in stats cards
    @api_this_month_cost = ApiUsageLog.this_month.sum(:estimated_cost)

    # Apps and providers with API usage for filter dropdowns
    @apps_with_api_usage = App.joins(:api_usage_logs).distinct.order(:name)
    @providers_with_usage = ServiceProvider.joins(:api_usage_logs).distinct.order(:name)
  end

  def load_combined_stats
    @total_monthly_cost = @render_monthly_cost + @api_this_month_cost
    @total_services_count = @render_total_services
  end
end
