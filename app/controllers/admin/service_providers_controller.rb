class Admin::ServiceProvidersController < Admin::BaseController
  before_action :set_service_provider, only: [:update, :destroy, :sync_now]

  def create
    @service_provider = ServiceProvider.new(service_provider_params)
    if @service_provider.save
      redirect_to admin_infrastructure_path(tab: "service_providers"), notice: "#{@service_provider.name} created."
    else
      redirect_to admin_infrastructure_path(tab: "service_providers"), alert: "Failed to create: #{@service_provider.errors.full_messages.join(', ')}"
    end
  end

  def update
    permitted = service_provider_params
    # Don't overwrite keys with placeholder
    permitted.delete(:api_key) if permitted[:api_key].blank? || permitted[:api_key].to_s.start_with?("\u2022")
    permitted.delete(:usage_api_key) if permitted[:usage_api_key].blank? || permitted[:usage_api_key].to_s.start_with?("\u2022")

    if @service_provider.update(permitted)
      redirect_to admin_infrastructure_path(tab: "service_providers"), notice: "#{@service_provider.name} updated."
    else
      redirect_to admin_infrastructure_path(tab: "service_providers"), alert: "Failed to update: #{@service_provider.errors.full_messages.join(', ')}"
    end
  end

  def destroy
    name = @service_provider.name
    @service_provider.destroy
    redirect_to admin_infrastructure_path(tab: "service_providers"), notice: "#{name} deleted."
  end

  def sync_now
    UsageSyncJob.perform_later(provider_id: @service_provider.id)
    redirect_to admin_infrastructure_path(tab: "service_providers"), notice: "Sync queued for #{@service_provider.name}."
  end

  private

  def set_service_provider
    @service_provider = ServiceProvider.find(params[:id])
  end

  def service_provider_params
    params.require(:service_provider).permit(
      :name, :slug, :category, :base_url, :api_key, :usage_api_key,
      :sync_adapter, :proxy_enabled, :sync_enabled, :active
    ).tap do |p|
      if params[:service_provider][:pricing_rules].present?
        p[:pricing_rules] = JSON.parse(params[:service_provider][:pricing_rules])
      end
      if params[:service_provider][:sync_config].present?
        p[:sync_config] = JSON.parse(params[:service_provider][:sync_config])
      end
    rescue JSON::ParserError
      # Leave as-is if invalid JSON
    end
  end
end
