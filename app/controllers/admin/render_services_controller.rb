class Admin::RenderServicesController < Admin::BaseController
  before_action :set_render_service, only: [:link, :unlink]

  def sync
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

  def link
    if params[:app_id].blank?
      redirect_to admin_infrastructure_path(tab: "render_services"), alert: "Please select an app to link."
      return
    end

    @app = App.find(params[:app_id])
    @render_service.update!(app: @app)

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace(@render_service, partial: "admin/render_services/service_row", locals: { service: @render_service, apps: App.order(:name) }) }
      format.html { redirect_to admin_infrastructure_path(tab: "render_services"), notice: "#{@render_service.name} linked to #{@app.name}." }
    end
  end

  def unlink
    app_name = @render_service.app&.name
    @render_service.update!(app: nil)

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace(dom_id(@render_service), partial: "admin/render_services/service_row", locals: { service: @render_service, apps: App.order(:name) }) }
      format.html do
        redirect_path = params[:redirect_to].presence || admin_infrastructure_path(tab: "render_services")
        redirect_to redirect_path, notice: "#{@render_service.name} unlinked from #{app_name}."
      end
    end
  end

  private

  def set_render_service
    @render_service = RenderService.find(params[:id])
  end
end
