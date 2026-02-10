# Load Stripe key from DB settings, falling back to env var
Rails.application.config.to_prepare do
  Stripe.api_key = Setting[:stripe_api_key].presence || ENV["STRIPE_API_KEY"] if defined?(Setting)
rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
  # DB not ready yet — fall back to env var
  Stripe.api_key = ENV["STRIPE_API_KEY"]
end
