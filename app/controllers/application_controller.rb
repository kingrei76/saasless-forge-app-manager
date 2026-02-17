class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  before_action :authenticate_user_from_token!
  before_action :authenticate_user!
  protect_from_forgery with: :exception, unless: :api_request?

  # Devise callback: trigger background sync for stale data on admin login
  def after_sign_in_path_for(resource)
    trigger_stale_syncs if resource.is_a?(User) && resource.admin?
    super
  end

  def stop_impersonating
    if session[:admin_id]
      admin = User.find(session.delete(:admin_id))
      sign_in(admin)
      redirect_to admin_root_path, notice: "Stopped impersonation"
    else
      redirect_to root_path
    end
  end

  private

  def authenticate_user_from_token!
    return unless api_request?

    token = request.headers['Authorization']&.match(/^Bearer\s+(.+)$/)&.captures&.first ||
            params['api_token']

    if token.present?
      # Check user API token first
      user = User.find_by(api_token: token)
      if user
        sign_in(user, store: false)
        return
      end

      # Check service-to-service token (LangGraph agent tools calling Rails APIs)
      service_token = Setting[:langgraph_auth_token] || ENV["LANGGRAPH_AUTH_TOKEN"]
      if service_token.present? && ActiveSupport::SecurityUtils.secure_compare(token, service_token)
        # Sign in as the admin user so agent operations have proper user context
        admin = User.where(admin: true).order(:id).first
        if admin
          sign_in(admin, store: false)
          return
        end
      end
    end

    render json: { error: 'Invalid API token' }, status: :unauthorized
  end

  def api_request?
    request.headers['Authorization']&.start_with?('Bearer ') ||
    params['api_token'].present?
  end

  def trigger_stale_syncs
    stale_threshold = 1.hour.ago

    GithubAccount.where("last_synced_at IS NULL OR last_synced_at < ?", stale_threshold).find_each do |account|
      GithubAccountSyncJob.perform_later(account.id)
    end
  end


end
