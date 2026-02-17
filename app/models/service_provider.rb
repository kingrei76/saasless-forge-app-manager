class ServiceProvider < ApplicationRecord
  encrypts :api_key, :usage_api_key

  has_many :ai_models, dependent: :destroy
  has_many :app_service_configs, dependent: :destroy
  has_many :apps, through: :app_service_configs
  has_many :api_usage_logs

  validates :name, :slug, :category, presence: true
  validates :slug, uniqueness: true

  scope :active, -> { where(active: true) }
  scope :by_category, ->(cat) { where(category: cat) }
  scope :proxyable, -> { where(proxy_enabled: true, active: true) }
  scope :syncable, -> { where(sync_enabled: true, active: true) }

  CATEGORIES = %w[llm image sms email analytics storage other].freeze

  def calculate_cost(usage_data)
    case pricing_rules["type"]
    when "per_token"  then calculate_token_cost(usage_data)
    when "per_unit"   then calculate_unit_cost(usage_data)
    when "tiered"     then calculate_tiered_cost(usage_data)
    else 0
    end
  end

  def sync_adapter_class
    return nil unless sync_adapter.present?
    sync_adapter.constantize
  rescue NameError => e
    Rails.logger.error("Unknown sync adapter: #{sync_adapter} — #{e.message}")
    nil
  end

  def api_key_configured?
    api_key.present?
  end

  def category_badge_color
    case category
    when "llm"       then "primary"
    when "image"     then "secondary"
    when "sms"       then "accent"
    when "email"     then "info"
    when "analytics" then "warning"
    when "storage"   then "success"
    else "ghost"
    end
  end

  private

  def calculate_token_cost(data)
    model_pricing = pricing_rules.dig("models", data[:model])
    return 0 unless model_pricing
    input_cost  = (data[:input_tokens].to_f / 1_000_000) * model_pricing["input"].to_f
    output_cost = (data[:output_tokens].to_f / 1_000_000) * model_pricing["output"].to_f
    input_cost + output_cost
  end

  def calculate_unit_cost(data)
    data[:quantity].to_f * pricing_rules["cost"].to_f
  end

  def calculate_tiered_cost(data)
    free = pricing_rules["free_tier"].to_i
    billable = [data[:quantity].to_i - free, 0].max
    billable * pricing_rules["overage_cost"].to_f
  end
end
