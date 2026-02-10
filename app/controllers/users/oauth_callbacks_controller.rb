class Users::OauthCallbacksController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :authenticate_user_from_token!

  def google
    redirect_uri = auth_google_callback_url

    service = GoogleOauthService.new(code: params[:code], redirect_uri: redirect_uri)
    user_info = service.authenticate

    if user_info.nil?
      redirect_to new_user_session_path, alert: "Google authentication failed. Please try again."
      return
    end

    user = User.find_or_create_from_oauth(**user_info)
    sign_in(user)
    redirect_to admin_root_path, notice: "Signed in with Google"
  rescue StandardError => e
    Rails.logger.error("OAuth callback error: #{e.message}")
    redirect_to new_user_session_path, alert: "Authentication error. Please try again."
  end
end
