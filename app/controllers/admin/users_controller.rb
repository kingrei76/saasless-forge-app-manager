class Admin::UsersController < Admin::BaseController
  def index
    @users = User.order(:name, :email)
    @allowed_emails = AllowedEmail.order(:email)
    @allowed_email = AllowedEmail.new
  end

  def create
    @allowed_email = AllowedEmail.new(allowed_email_params)
    if @allowed_email.save
      redirect_to admin_users_path, notice: "#{@allowed_email.email} has been authorized."
    else
      @users = User.order(:name, :email)
      @allowed_emails = AllowedEmail.order(:email)
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    allowed_email = AllowedEmail.find(params[:id])
    allowed_email.destroy
    redirect_to admin_users_path, notice: "#{allowed_email.email} has been removed."
  end

  def impersonate
    user = User.find(params[:id])
    session[:admin_id] = current_user.id
    sign_in(user)
    redirect_to root_path, notice: "Now impersonating #{user.email}"
  end

  private

  def allowed_email_params
    params.require(:allowed_email).permit(:email)
  end
end
