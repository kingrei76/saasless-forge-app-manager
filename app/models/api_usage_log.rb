class ApiUsageLog < ApplicationRecord
  belongs_to :trackable, polymorphic: true, optional: true
  belongs_to :app, optional: true

  validates :provider, presence: true
  validates :model, presence: true

  scope :grok, -> { where(provider: "grok") }
  scope :this_month, -> { where("api_usage_logs.created_at >= ?", Time.current.beginning_of_month) }
  scope :last_month, -> { where(api_usage_logs: { created_at: 1.month.ago.beginning_of_month..1.month.ago.end_of_month }) }
  scope :for_app, ->(app) { where(app: app) }
  scope :with_app, -> { where.not(app_id: nil) }
  scope :without_app, -> { where(app_id: nil) }

  # Grok pricing (per million tokens) - update as needed
  GROK_PRICING = {
    "grok-3" => { input: 3.00, output: 15.00 },
    "grok-2-latest" => { input: 2.00, output: 10.00 },
    "grok-beta" => { input: 5.00, output: 15.00 }
  }.freeze

  def calculate_cost!
    pricing = GROK_PRICING[model] || GROK_PRICING["grok-3"]
    input_cost = (input_tokens.to_f / 1_000_000) * pricing[:input]
    output_cost = (output_tokens.to_f / 1_000_000) * pricing[:output]
    self.estimated_cost = input_cost + output_cost
    save! if persisted?
    estimated_cost
  end

  def self.monthly_total(month: Time.current)
    where(created_at: month.beginning_of_month..month.end_of_month)
      .sum(:estimated_cost)
  end

  def self.monthly_tokens(month: Time.current)
    where(created_at: month.beginning_of_month..month.end_of_month)
      .sum("COALESCE(input_tokens, 0) + COALESCE(output_tokens, 0)")
  end

  def self.by_operation
    group(:operation).select(
      "operation",
      "COUNT(*) as call_count",
      "SUM(input_tokens) as total_input_tokens",
      "SUM(output_tokens) as total_output_tokens",
      "SUM(estimated_cost) as total_cost"
    )
  end

  def self.by_app
    group(:app_id).select(
      "app_id",
      "COUNT(*) as call_count",
      "SUM(input_tokens) as total_input_tokens",
      "SUM(output_tokens) as total_output_tokens",
      "SUM(estimated_cost) as total_cost"
    )
  end

  def self.costs_by_app
    joins(:app).group("apps.id", "apps.name").select(
      "apps.id as app_id",
      "apps.name as app_name",
      "COUNT(*) as call_count",
      "SUM(estimated_cost) as total_cost"
    )
  end
end
