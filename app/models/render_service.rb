class RenderService < ApplicationRecord
  belongs_to :app, optional: true
  belongs_to :render_workspace, primary_key: :render_owner_id, foreign_key: :render_owner_id, optional: true

  validates :render_service_id, presence: true, uniqueness: true
  validates :name, presence: true

  scope :linked, -> { where.not(app_id: nil) }
  scope :unlinked, -> { where(app_id: nil) }
  scope :by_type, ->(type) { where(service_type: type) if type.present? }
  scope :by_owner, ->(owner_id) { where(render_owner_id: owner_id) if owner_id.present? }
  scope :active, -> { where(suspended: false) }

  SERVICE_PLAN_PRICES = {
    "free" => 0,
    "starter" => 7,
    "standard" => 25,
    "pro" => 85,
    "pro_plus" => 175,
    "pro_max" => 225,
    "pro_ultra" => 450
  }.freeze

  DATABASE_PLAN_PRICES = {
    "free" => 0,
    "basic_256mb" => 6,
    "basic_1gb" => 19,
    "basic_4gb" => 75,
    "pro_4gb" => 55,
    "pro_8gb" => 100,
    "pro_16gb" => 200,
    "pro_32gb" => 400
  }.freeze

  REDIS_PLAN_PRICES = {
    "free" => 0,
    "starter" => 10,
    "standard" => 45,
    "pro" => 85
  }.freeze

  SERVICE_TYPE_LABELS = {
    "web_service" => "Web Service",
    "private_service" => "Private Service",
    "background_worker" => "Background Worker",
    "cron_job" => "Cron Job",
    "postgres" => "PostgreSQL",
    "redis" => "Redis",
    "static_site" => "Static Site"
  }.freeze

  def monthly_price
    price = RenderPrice.current_price(service_type: service_type || "web_service", plan_name: plan)
    return price if price > 0

    case service_type
    when "postgres"
      DATABASE_PLAN_PRICES[plan] || 0
    when "redis"
      REDIS_PLAN_PRICES[plan] || 0
    else
      SERVICE_PLAN_PRICES[plan] || 0
    end
  end

  def service_type_label
    SERVICE_TYPE_LABELS[service_type] || service_type&.titleize || "Unknown"
  end

  def display_name
    "#{name} (#{service_type_label})"
  end

  def linked?
    app_id.present?
  end

  def service_icon
    case service_type
    when "web_service", "private_service", "background_worker"
      "fa-server"
    when "postgres"
      "fa-database"
    when "redis"
      "fa-bolt"
    when "cron_job"
      "fa-clock"
    when "static_site"
      "fa-file-code"
    else
      "fa-cloud"
    end
  end
end
