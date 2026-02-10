class Admin::SettingsController < Admin::BaseController
  before_action :require_admin!

  def show
    @settings = {
      default_markup_percentage: Setting[:default_markup_percentage] || "30.0",
      default_hourly_rate: Setting[:default_hourly_rate] || "150.0",
      stripe_api_key: Setting[:stripe_api_key] || ENV["STRIPE_API_KEY"].to_s,
      stripe_publishable_key: Setting[:stripe_publishable_key] || ENV["STRIPE_PUBLISHABLE_KEY"].to_s,
      stripe_webhook_signing_secret: Setting[:stripe_webhook_signing_secret] || ENV["STRIPE_WEBHOOK_SECRET"].to_s,
      grok_api_key: Setting[:grok_api_key] || ""
    }
    @grok_usage_this_month = ApiUsageLog.grok.this_month.sum(:estimated_cost)
    @grok_calls_this_month = ApiUsageLog.grok.this_month.count
  end

  def update
    params[:settings]&.each do |key, value|
      old_value = Setting[key]
      Setting[key] = value

      if old_value != value
        AuditLogger.log(
          user: current_user,
          action: "setting_changed",
          auditable: Setting.find_by(key: key),
          changes_data: { key: key, from: old_value, to: value }
        )
      end
    end

    # Update Stripe config if key was changed
    if params[:settings]&.key?(:stripe_api_key) && params[:settings][:stripe_api_key].present?
      Stripe.api_key = params[:settings][:stripe_api_key]
    end

    redirect_to admin_settings_path, notice: "Settings updated."
  end

  def test_grok_connection
    result = GrokApiService.new.test_connection
    if result[:success]
      redirect_to admin_settings_path, notice: "Grok connection successful!"
    else
      redirect_to admin_settings_path, alert: "Grok connection failed: #{result[:error]}"
    end
  rescue => e
    redirect_to admin_settings_path, alert: "Grok connection failed: #{e.message}"
  end
end
