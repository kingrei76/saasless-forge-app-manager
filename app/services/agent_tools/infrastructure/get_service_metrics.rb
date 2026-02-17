# frozen_string_literal: true

module AgentTools
  module Infrastructure
    class GetServiceMetrics < AgentTools::Base
      def self.tool_name = "Get Service Metrics"
      def self.tool_description = "Get CPU, memory, or bandwidth metrics for a Render service over a time range. Returns time-series data from the Render API."
      def self.tool_category = "api"
      def self.tool_risk_level = "low"

      def self.tool_input_schema
        {
          type: "object",
          properties: {
            app_id: { type: "integer", description: "App ID" },
            metric: { type: "string", enum: %w[cpu memory bandwidth], description: "Metric type" },
            from_date: { type: "string", description: "Start date (YYYY-MM-DD), default 7 days ago" },
            to_date: { type: "string", description: "End date (YYYY-MM-DD), default today" },
            resolution: { type: "string", enum: %w[1h 6h 1d], description: "Data resolution (default 1h)" }
          },
          required: %w[app_id metric]
        }
      end

      def call(input_data)
        app = App.find(input_data["app_id"])
        return { error: "App '#{app.name}' has no Render service configured" } unless app.render_service_id.present?

        from_date = input_data["from_date"] ? Date.parse(input_data["from_date"]) : 7.days.ago
        to_date = input_data["to_date"] ? Date.parse(input_data["to_date"]).end_of_day : Time.current
        resolution = input_data["resolution"] || "1h"

        api = RenderApiService.new

        metrics = case input_data["metric"]
        when "cpu"
          api.get_cpu_metrics(app.render_service_id, from: from_date.iso8601, to: to_date.iso8601, resolution: resolution)
        when "memory"
          api.get_memory_metrics(app.render_service_id, from: from_date.iso8601, to: to_date.iso8601, resolution: resolution)
        when "bandwidth"
          api.get_bandwidth_metrics(app.render_service_id, from: from_date.iso8601, to: to_date.iso8601, resolution: resolution)
        else
          return { error: "Unknown metric type: #{input_data["metric"]}" }
        end

        {
          app_name: app.name,
          metric: input_data["metric"],
          from: from_date.to_s,
          to: to_date.to_s,
          resolution: resolution,
          data_points: metrics.is_a?(Array) ? metrics.size : 0,
          metrics: metrics
        }
      rescue ActiveRecord::RecordNotFound
        { error: "App not found with ID #{input_data["app_id"]}" }
      rescue => e
        { error: e.message }
      end
    end
  end
end
