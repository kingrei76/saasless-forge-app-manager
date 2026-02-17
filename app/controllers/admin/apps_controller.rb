class Admin::AppsController < Admin::BaseController
  before_action :set_app, only: [:show, :update, :toggle_included]

  def index
    @apps = App.includes(:github_account, :clients)
    @apps = @apps.where(app_type: params[:app_type]) if params[:app_type].present?
    @apps = @apps.search(params[:search])
    @apps = @apps.order(:name)
  end

  def show
    @cost_entries = @app.cost_entries.order(period_start: :desc).limit(10)
    @clients = @app.clients.includes(:projects)
    @bids = Bid.joins(:bid_apps).where(bid_apps: { app_id: @app.id }).order(created_at: :desc).limit(5)
    @commits = fetch_recent_commits(limit: 10)
    @projects = Project.where(client: @clients).order(created_at: :desc).limit(5)
    @cost_by_month = @app.cost_entries
                         .where("period_start >= ?", 6.months.ago.beginning_of_month)
                         .group("DATE_TRUNC('month', period_start)")
                         .sum(:amount)
    @available_providers = ServiceProvider.active
      .where.not(id: @app.app_service_configs.select(:service_provider_id))
      .order(:name)
  end

  def update
    if @app.update(app_params)
      redirect_to admin_app_path(@app), notice: "App updated."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def toggle_included
    @app.update!(included: !@app.included)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to admin_apps_path }
    end
  end

  def sync
    accounts = if params[:github_account_id].present?
      GithubAccount.where(id: params[:github_account_id])
    else
      GithubAccount.all
    end

    total_synced = 0
    total_filtered = 0
    errors = []

    accounts.each do |account|
      result = GithubSyncService.new(account).sync!
      total_synced += result[:synced].to_i
      total_filtered += result[:filtered].to_i
    rescue StandardError => e
      errors << "#{account.display_name}: #{e.message}"
    end

    notice = "Synced #{total_synced} repos from #{accounts.count} account(s)."
    notice += " #{total_filtered} filtered (outside org)." if total_filtered > 0
    notice += " Errors: #{errors.join('; ')}" if errors.any?

    redirect_to admin_apps_path, notice: notice
  rescue StandardError => e
    redirect_to admin_apps_path, alert: "Sync failed: #{e.message}"
  end

  private

  def set_app
    @app = App.find(params[:id])
  end

  def app_params
    permitted = params.require(:app).permit(:status, :included, :ai_api_key, :app_type, tags: [])
    # Don't overwrite API key with placeholder or empty value
    if permitted[:ai_api_key].blank? || permitted[:ai_api_key].to_s.start_with?("\u2022")
      permitted.delete(:ai_api_key)
    end
    permitted
  end

  def fetch_recent_commits(limit: 10)
    return [] unless @app.github_account&.access_token.present?
    return [] unless @app.full_name.present?

    GithubApiService.new(access_token: @app.github_account.access_token)
                    .commits(repo: @app.full_name, branch: @app.default_branch, per_page: limit)
  rescue => e
    Rails.logger.error("Failed to fetch commits for #{@app.full_name}: #{e.message}")
    []
  end
end
