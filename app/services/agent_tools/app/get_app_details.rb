# frozen_string_literal: true

module AgentTools
  module App
    class GetAppDetails < AgentTools::Base
      def self.tool_name = "Get App Details"
      def self.tool_description = "Get full details for a specific app including hosting, cost info, associated clients, and service providers."
      def self.tool_category = "database"
      def self.tool_risk_level = "low"

      def self.tool_input_schema
        {
          type: "object",
          properties: {
            app_id: { type: "integer", description: "App ID" }
          },
          required: ["app_id"]
        }
      end

      def call(input_data)
        app = ::App.includes(:clients, :cost_entries, :service_providers).find(input_data["app_id"])

        current_month_start = Date.current.beginning_of_month
        current_month_end = Date.current.end_of_month

        {
          app: {
            id: app.id,
            name: app.name,
            full_name: app.full_name,
            included: app.included,
            render_service_id: app.render_service_id,
            render_service_type: app.render_service_type,
            render_plan: app.render_plan,
            github_repo_id: app.github_repo_id
          },
          costs: {
            total_monthly: app.total_monthly_cost.to_f,
            render_monthly: app.total_render_monthly_cost.to_f,
            api_this_month: app.api_cost_this_month.to_f,
            current_period: app.total_cost(period_start: current_month_start, period_end: current_month_end).to_f
          },
          clients: app.clients.map { |c| { id: c.id, name: c.name } },
          service_providers: app.service_providers.map { |sp| { id: sp.id, name: sp.name, category: sp.category } },
          recent_cost_entries: app.cost_entries.order(created_at: :desc).limit(10).map { |ce|
            {
              service_name: ce.service_name,
              amount: ce.amount.to_f,
              period: "#{ce.period_start} - #{ce.period_end}",
              source_type: ce.source_type
            }
          }
        }
      rescue ActiveRecord::RecordNotFound
        { error: "App not found with ID #{input_data["app_id"]}" }
      rescue => e
        { error: e.message }
      end
    end
  end
end
