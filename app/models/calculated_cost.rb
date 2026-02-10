class CalculatedCost < ApplicationRecord
  belongs_to :app
  belongs_to :client

  validates :billing_period_start, presence: true
  validates :billing_period_end, presence: true
  validates :total_cost, numericality: { greater_than_or_equal_to: 0 }

  scope :for_client, ->(client_id) { where(client_id: client_id) }
  scope :for_app, ->(app_id) { where(app_id: app_id) }
  scope :current_period, ->(client) {
    start_date, end_date = client.current_billing_period
    where(billing_period_start: start_date, billing_period_end: end_date)
  }
  scope :in_period, ->(start_date, end_date) {
    where(billing_period_start: start_date, billing_period_end: end_date)
  }

  def self.total_for_client(client_id, start_date, end_date)
    for_client(client_id)
      .in_period(start_date, end_date)
      .sum(:total_cost)
  end

  def self.projected_total_for_client(client_id, start_date, end_date)
    for_client(client_id)
      .in_period(start_date, end_date)
      .sum(:projected_monthly_cost)
  end

  def self.grouped_by_app(client_id, start_date, end_date)
    for_client(client_id)
      .in_period(start_date, end_date)
      .includes(:app)
      .group_by(&:app)
  end

  def cost_per_day
    return 0 if days_active.to_i.zero?
    total_cost / days_active
  end
end
