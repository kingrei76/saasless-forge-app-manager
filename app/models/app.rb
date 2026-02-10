class App < ApplicationRecord
  encrypts :ai_api_key

  belongs_to :github_account
  belongs_to :render_workspace, primary_key: :render_owner_id, foreign_key: :render_owner_id, optional: true
  has_many :app_assignments, dependent: :destroy
  has_many :clients, through: :app_assignments
  has_many :project_apps, dependent: :nullify
  has_many :projects, through: :project_apps
  has_many :cost_entries, dependent: :destroy
  has_many :invoice_line_items, dependent: :nullify
  has_many :render_usage_metrics, dependent: :destroy
  has_many :calculated_costs, dependent: :destroy
  has_many :render_services, dependent: :nullify
  has_many :api_usage_logs, dependent: :nullify

  validates :github_repo_id, uniqueness: true, allow_nil: true
  validates :render_service_id, uniqueness: true, allow_nil: true

  scope :included, -> { where(included: true) }
  scope :excluded, -> { where(included: false) }
  scope :by_account, ->(account_id) { where(github_account_id: account_id) if account_id.present? }
  scope :search, ->(query) { where("name ILIKE ? OR full_name ILIKE ?", "%#{query}%", "%#{query}%") if query.present? }
  scope :with_render, -> { where.not(render_service_id: nil) }
  scope :by_render_owner, ->(owner_id) { where(render_owner_id: owner_id) if owner_id.present? }

  def total_cost(period_start: nil, period_end: nil)
    entries = cost_entries
    entries = entries.where("period_start >= ?", period_start) if period_start
    entries = entries.where("period_end <= ?", period_end) if period_end
    entries.sum(:amount)
  end

  def has_render_service?
    render_service_id.present?
  end

  def has_ai_api_key?
    ai_api_key.present?
  end

  def render_service_display
    return nil unless has_render_service?
    "#{render_service_type} (#{render_plan})"
  end

  def total_render_monthly_cost
    render_services.active.sum(&:monthly_price)
  end

  def has_render_services?
    render_services.exists?
  end

  def calculated_cost_for_period(client:, start_date:, end_date:)
    calculated_costs
      .for_client(client.id)
      .in_period(start_date, end_date)
      .sum(:total_cost)
  end

  def projected_cost_for_period(client:, start_date:, end_date:)
    calculated_costs
      .for_client(client.id)
      .in_period(start_date, end_date)
      .sum(:projected_monthly_cost)
  end

  def api_cost(period_start: nil, period_end: nil)
    logs = api_usage_logs
    logs = logs.where("created_at >= ?", period_start) if period_start
    logs = logs.where("created_at <= ?", period_end) if period_end
    logs.sum(:estimated_cost)
  end

  def api_cost_this_month
    api_usage_logs.this_month.sum(:estimated_cost)
  end

  def total_monthly_cost
    total_render_monthly_cost + api_cost_this_month
  end
end
