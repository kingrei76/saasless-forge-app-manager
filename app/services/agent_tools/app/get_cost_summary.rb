# frozen_string_literal: true

module AgentTools
  module App
    class GetCostSummary < AgentTools::Base
      def self.tool_name = "Get Cost Summary"
      def self.tool_description = "Get cost summary across all apps or for a specific client. Shows infrastructure costs, API costs, and billing totals for a given period."
      def self.tool_category = "database"
      def self.tool_risk_level = "low"

      def self.tool_input_schema
        {
          type: "object",
          properties: {
            client_id: { type: "integer", description: "Client ID (omit for all-app summary)" },
            period_start: { type: "string", description: "Start date (YYYY-MM-DD), default: start of current month" },
            period_end: { type: "string", description: "End date (YYYY-MM-DD), default: end of current month" }
          }
        }
      end

      def call(input_data)
        period_start = input_data["period_start"] ? Date.parse(input_data["period_start"]) : Date.current.beginning_of_month
        period_end = input_data["period_end"] ? Date.parse(input_data["period_end"]) : Date.current.end_of_month

        if input_data["client_id"].present?
          client = Client.find(input_data["client_id"])
          client_cost_summary(client, period_start, period_end)
        else
          global_cost_summary(period_start, period_end)
        end
      rescue ActiveRecord::RecordNotFound
        { error: "Client not found with ID #{input_data["client_id"]}" }
      rescue => e
        { error: e.message }
      end

      private

      def client_cost_summary(client, period_start, period_end)
        apps = client.apps.included
        app_costs = apps.map { |app|
          {
            app_name: app.name,
            total: app.total_cost(period_start: period_start, period_end: period_end).to_f,
            render: app.total_render_monthly_cost.to_f,
            api: app.api_cost_this_month.to_f
          }
        }

        {
          client: { id: client.id, name: client.name },
          period: { start: period_start.to_s, end: period_end.to_s },
          app_costs: app_costs,
          total_cost: app_costs.sum { |a| a[:total] },
          markup_percentage: client.effective_markup,
          markup_total: app_costs.sum { |a| a[:total] } * (client.effective_markup.to_f / 100)
        }
      end

      def global_cost_summary(period_start, period_end)
        entries = CostEntry.where("period_start >= ? OR period_end <= ?", period_start, period_end)

        by_service = entries.group(:service_name).sum(:amount).transform_values(&:to_f)
        by_app = entries.joins(:app).group("apps.name").sum(:amount).transform_values(&:to_f)

        {
          period: { start: period_start.to_s, end: period_end.to_s },
          total_cost: entries.sum(:amount).to_f,
          by_service: by_service,
          by_app: by_app.sort_by { |_, v| -v }.first(20).to_h,
          entry_count: entries.count
        }
      end
    end
  end
end
