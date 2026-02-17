class AiModel < ApplicationRecord
  belongs_to :service_provider
  has_many :agents

  validates :name, :model_id, :category, :status, presence: true
  validates :model_id, uniqueness: { scope: :service_provider_id }
  validates :category, inclusion: { in: %w[chat embedding image audio] }
  validates :status, inclusion: { in: %w[active deprecated disabled] }

  scope :active, -> { where(status: "active") }
  scope :chat_models, -> { where(category: "chat") }
  scope :available, -> {
    active
      .joins(:service_provider)
      .where(service_providers: { proxy_enabled: true, active: true })
      .order("service_providers.name ASC, ai_models.sort_order ASC, ai_models.name ASC")
  }

  CATEGORIES = %w[chat embedding image audio].freeze
  STATUSES = %w[active deprecated disabled].freeze

  def display_label
    "#{name} (#{service_provider.name})"
  end

  def calculate_cost(input_tokens:, output_tokens:)
    input_cost = (input_tokens.to_f / 1_000_000) * (input_price_per_million || 0)
    output_cost = (output_tokens.to_f / 1_000_000) * (output_price_per_million || 0)
    input_cost + output_cost
  end
end
