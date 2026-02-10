class Admin::InfrastructureController < Admin::BaseController
  def show
    @tab = params[:tab] || "render_services"
    @period = params[:period] || "this_month"

    load_render_services_data
    load_api_usage_data
    load_combined_stats
  end

  def assign_api_logs
    app = App.find(params[:app_id])
    count = ApiUsageLog.without_app.update_all(app_id: app.id)
    redirect_to admin_infrastructure_path(tab: "ai_apis"),
                notice: "Assigned #{count} API usage logs to #{app.name}"
  end

  def sync_render
    accounts_with_render = GithubAccount.with_render

    if accounts_with_render.empty?
      redirect_to admin_infrastructure_path, alert: "No GitHub accounts have Render API keys configured. Please configure Render in GitHub Accounts."
      return
    end

    total_results = { services_synced: 0, services_created: 0, services_updated: 0 }
    errors = []

    accounts_with_render.each do |account|
      begin
        result = RenderSyncService.new(github_account: account).sync_render_services
        account.update!(render_last_synced_at: Time.current)

        total_results[:services_synced] += result[:services_synced].to_i
        total_results[:services_created] += result[:services_created].to_i
        total_results[:services_updated] += result[:services_updated].to_i
      rescue StandardError => e
        Rails.logger.error "Render sync failed for #{account.account_name}: #{e.message}"
        errors << "#{account.display_name}: #{e.message}"
      end
    end

    notice = "Synced #{total_results[:services_synced]} Render services from #{accounts_with_render.count} account(s)"
    notice += " (#{total_results[:services_created]} new, #{total_results[:services_updated]} updated)" if total_results[:services_created] > 0 || total_results[:services_updated] > 0

    if errors.any?
      redirect_to admin_infrastructure_path(tab: "render_services"), alert: "#{notice}. Errors: #{errors.join('; ')}"
    else
      redirect_to admin_infrastructure_path(tab: "render_services"), notice: notice
    end
  rescue StandardError => e
    Rails.logger.error "Render sync failed: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    redirect_to admin_infrastructure_path(tab: "render_services"), alert: "Sync failed: #{e.message}"
  end

  private

  def load_render_services_data
    @render_services = RenderService.includes(:app, :render_workspace).order(:name)

    # Filters
    if params[:github_account_id].present?
      app_ids = GithubAccount.find(params[:github_account_id]).apps.pluck(:id)
      @render_services = @render_services.where(app_id: app_ids)
    end
    @render_services = @render_services.by_type(params[:service_type]) if params[:service_type].present?
    @render_services = @render_services.by_owner(params[:owner_id]) if params[:owner_id].present?

    if params[:linked] == "true"
      @render_services = @render_services.linked
    elsif params[:linked] == "false"
      @render_services = @render_services.unlinked
    end

    @apps = App.order(:name)
    @workspaces = RenderWorkspace.order(:name)
    @github_accounts = GithubAccount.with_render.order(:account_name)
    @service_types = RenderService.distinct.pluck(:service_type).compact.sort

    # Render stats
    @render_total_services = RenderService.count
    @render_linked_count = RenderService.linked.count
    @render_unlinked_count = RenderService.unlinked.count
    @render_monthly_cost = RenderService.active.sum { |s| s.monthly_price }
  end

  def load_api_usage_data
    base_scope = ApiUsageLog.grok

    @api_logs = case @period
    when "last_month"
      base_scope.last_month
    when "all_time"
      base_scope
    else # this_month
      base_scope.this_month
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
    @api_this_month_cost = ApiUsageLog.grok.this_month.sum(:estimated_cost)

    # Apps with API usage for filter dropdown
    @apps_with_api_usage = App.joins(:api_usage_logs).distinct.order(:name)
  end

  def load_combined_stats
    @total_monthly_cost = @render_monthly_cost + @api_this_month_cost
    @total_services_count = @render_total_services
  end
end
