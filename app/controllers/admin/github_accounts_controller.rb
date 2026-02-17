class Admin::GithubAccountsController < Admin::BaseController
  MASKED_KEY_PLACEHOLDER = "••••••••••••••••"

  before_action :require_admin!
  before_action :set_github_account, only: [:show, :edit, :update, :destroy]

  def index
    @github_accounts = GithubAccount.includes(:user).order(:account_name)
  end

  def show; end

  def new
    @github_account = current_user.github_accounts.build
  end

  def create
    @github_account = current_user.github_accounts.build(github_account_params)

    if @github_account.save
      redirect_to admin_github_account_path(@github_account), notice: "GitHub account added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    update_params = github_account_params
    # Don't clear render_api_key if blank or unchanged (user kept the masked placeholder)
    if update_params[:render_api_key].blank? || update_params[:render_api_key] == MASKED_KEY_PLACEHOLDER
      update_params = update_params.except(:render_api_key)
    end

    if @github_account.update(update_params)
      redirect_to admin_github_account_path(@github_account), notice: "GitHub account updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @github_account.destroy
    redirect_to admin_github_accounts_path, notice: "GitHub account removed."
  end

  def test_connection
    account = GithubAccount.find(params[:id])
    api = GithubApiService.new(access_token: account.access_token)
    result = api.test_connection

    if result[:success]
      render json: { success: true, user: result[:user]["login"] }
    else
      render json: { success: false, error: result[:error] }, status: :unprocessable_entity
    end
  end

  def sync_all
    accounts = GithubAccount.all
    total_synced = 0
    total_render = 0
    errors = []

    accounts.each do |account|
      result = GithubSyncService.new(account).sync!
      total_synced += result[:synced].to_i

      if account.render_configured?
        RenderSyncService.new(github_account: account).sync_render_services
        account.update!(render_last_synced_at: Time.current)
        total_render += 1
      end
    rescue StandardError => e
      errors << "#{account.display_name}: #{e.message}"
    end

    notice = "Synced #{total_synced} repos from #{accounts.count} GitHub account(s)"
    notice += ", #{total_render} Render account(s)" if total_render > 0
    notice += ". Errors: #{errors.join('; ')}" if errors.any?

    redirect_to admin_github_accounts_path, notice: notice
  end

  def sync
    account = GithubAccount.find(params[:id])
    result = GithubSyncService.new(account).sync!

    notice = "Synced #{result[:synced]} repos."
    notice += " (#{result[:skipped]} skipped - already synced from another account)" if result[:skipped].to_i > 0

    redirect_to admin_github_account_path(account), notice: notice
  rescue StandardError => e
    redirect_to admin_github_account_path(account), alert: "Sync failed: #{e.message}"
  end

  def test_render_connection
    account = GithubAccount.find(params[:id])

    unless account.render_configured?
      render json: { success: false, error: "No Render API key configured" }, status: :unprocessable_entity
      return
    end

    api = RenderApiService.new(api_key: account.render_api_key)
    owners = api.list_owners

    if owners.present?
      owner_names = owners.map { |o| o.dig("owner", "name") }.compact.join(", ")
      render json: { success: true, message: "Connected! Workspaces: #{owner_names}" }
    else
      render json: { success: true, message: "Connected! No workspaces found." }
    end
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  def sync_render
    account = GithubAccount.find(params[:id])

    unless account.render_configured?
      redirect_to admin_github_account_path(account), alert: "No Render API key configured."
      return
    end

    result = RenderSyncService.new(github_account: account).sync_render_services
    account.update!(render_last_synced_at: Time.current)

    notice = "Synced #{result[:services_synced]} Render services"
    notice += " (#{result[:services_created]} new, #{result[:services_updated]} updated)" if result[:services_created].to_i > 0 || result[:services_updated].to_i > 0

    redirect_to admin_github_account_path(account), notice: notice
  rescue StandardError => e
    Rails.logger.error "Render sync failed for #{account.account_name}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    redirect_to admin_github_account_path(account), alert: "Render sync failed: #{e.message}"
  end

  private

  def set_github_account
    @github_account = GithubAccount.find(params[:id])
  end

  def github_account_params
    params.require(:github_account).permit(:account_name, :access_token, :label, :render_api_key)
  end
end

