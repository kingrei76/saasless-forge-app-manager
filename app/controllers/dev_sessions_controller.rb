class DevSessionsController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :authenticate_user_from_token!

  def create
    unless ENV["SKIP_AUTH"] == "true"
      redirect_to new_user_session_path, alert: "Dev login not enabled"
      return
    end

    user = User.find_or_create_by!(email: "admin@apphub.dev") do |u|
      u.name = "Dev Admin"
      u.password = SecureRandom.hex(16)
      u.role = :admin
      u.admin = true
    end

    sign_in(user)
    redirect_to admin_root_path, notice: "Signed in as Dev Admin"
  end
end
