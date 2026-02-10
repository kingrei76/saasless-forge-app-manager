class RenderUsageMetric < ApplicationRecord
  belongs_to :app

  validates :render_service_id, presence: true
  validates :metric_type, presence: true, inclusion: { in: %w[cpu memory bandwidth disk] }
  validates :value, presence: true, numericality: true
  validates :unit, presence: true
  validates :period_start, presence: true
  validates :period_end, presence: true

  scope :for_app, ->(app_id) { where(app_id: app_id) }
  scope :for_service, ->(service_id) { where(render_service_id: service_id) }
  scope :for_type, ->(type) { where(metric_type: type) }
  scope :in_period, ->(start_time, end_time) {
    where("period_start >= ? AND period_end <= ?", start_time, end_time)
  }
  scope :recent, ->(hours = 24) { where("period_start >= ?", hours.hours.ago) }

  def self.aggregate_for_period(app_id:, metric_type:, start_time:, end_time:)
    for_app(app_id)
      .for_type(metric_type)
      .in_period(start_time, end_time)
      .average(:value)
  end

  def self.total_bandwidth_gb(app_id:, start_time:, end_time:)
    for_app(app_id)
      .for_type("bandwidth")
      .in_period(start_time, end_time)
      .sum(:value) / 1_073_741_824.0 # Convert bytes to GB
  end
end
