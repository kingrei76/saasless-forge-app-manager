class Admin::BaseController < ApplicationController
  before_action :authenticate_admin!
  layout "admin"

  private

  def authenticate_admin!
    redirect_to root_path unless current_user&.admin? || current_user&.partner?
  end

  def require_admin!
    redirect_to admin_root_path, alert: "Admin access required" unless current_user&.admin?
  end
end
