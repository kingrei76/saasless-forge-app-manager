class Admin::AppServiceConfigsController < Admin::BaseController
  before_action :set_app
  before_action :set_config, only: [:update, :destroy]

  def create
    @config = @app.app_service_configs.build(config_params)

    if @config.save
      redirect_to admin_app_path(@app), notice: "Provider connected successfully."
    else
      redirect_to admin_app_path(@app), alert: @config.errors.full_messages.join(", ")
    end
  end

  def update
    if @config.update(config_params)
      redirect_to admin_app_path(@app), notice: "Service config updated."
    else
      redirect_to admin_app_path(@app), alert: @config.errors.full_messages.join(", ")
    end
  end

  def destroy
    provider_name = @config.service_provider.name
    @config.destroy
    redirect_to admin_app_path(@app), notice: "Disconnected #{provider_name}."
  end

  private

  def set_app
    @app = App.find(params[:app_id])
  end

  def set_config
    @config = @app.app_service_configs.find(params[:id])
  end

  def config_params
    params.require(:app_service_config).permit(:service_provider_id, :enabled, :monthly_budget_limit, :external_identifier)
  end
end
