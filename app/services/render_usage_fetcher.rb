class RenderUsageFetcher
  def initialize(api_key: nil)
    @api = RenderApiService.new(api_key: api_key)
  end

  def fetch_all_apps(from: 24.hours.ago, to: Time.current)
    results = { fetched: 0, errors: [], apps_processed: 0 }

    App.with_render.find_each do |app|
      fetch_app_metrics(app, from: from, to: to, results: results)
      results[:apps_processed] += 1
    end

    results
  end

  def fetch_app_metrics(app, from:, to:, results: { fetched: 0, errors: [] })
    return results unless app.render_service_id.present?

    service_id = app.render_service_id

    # Fetch each metric type
    %w[cpu memory bandwidth].each do |metric_type|
      begin
        metrics = fetch_metric(service_id, metric_type, from, to)
        store_metrics(app, service_id, metric_type, metrics, results)
      rescue => e
        results[:errors] << { app_id: app.id, metric: metric_type, error: e.message }
      end
    end

    results
  end

  private

  def fetch_metric(service_id, metric_type, from, to)
    case metric_type
    when "cpu"
      @api.get_cpu_metrics(service_id, from: from, to: to)
    when "memory"
      @api.get_memory_metrics(service_id, from: from, to: to)
    when "bandwidth"
      @api.get_bandwidth_metrics(service_id, from: from, to: to)
    else
      []
    end
  end

  def store_metrics(app, service_id, metric_type, metrics_data, results)
    return if metrics_data.blank? || !metrics_data.is_a?(Array)

    metrics_data.each do |data_point|
      # Handle different response formats from Render API
      timestamp = parse_timestamp(data_point["time"] || data_point["timestamp"])
      value = data_point["value"].to_f
      unit = determine_unit(metric_type)

      next if timestamp.nil?

      # Create hourly buckets
      period_start = timestamp.beginning_of_hour
      period_end = period_start + 1.hour

      metric = RenderUsageMetric.find_or_initialize_by(
        app_id: app.id,
        render_service_id: service_id,
        metric_type: metric_type,
        period_start: period_start
      )

      metric.assign_attributes(
        value: value,
        unit: unit,
        period_end: period_end,
        raw_data: data_point
      )

      if metric.save
        results[:fetched] += 1
      end
    end
  end

  def parse_timestamp(time_value)
    case time_value
    when Time, DateTime
      time_value.to_time
    when String
      Time.parse(time_value)
    when Integer
      Time.at(time_value)
    else
      nil
    end
  rescue => e
    Rails.logger.warn "Failed to parse timestamp #{time_value}: #{e.message}"
    nil
  end

  def determine_unit(metric_type)
    case metric_type
    when "cpu"
      "percent"
    when "memory"
      "bytes"
    when "bandwidth"
      "bytes"
    else
      "unknown"
    end
  end
end
