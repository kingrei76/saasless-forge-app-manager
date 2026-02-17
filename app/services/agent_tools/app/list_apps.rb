# frozen_string_literal: true

module AgentTools
  module App
    class ListApps < AgentTools::Base
      def self.tool_name = "List Apps"
      def self.tool_description = "List all tracked applications with optional filtering. Returns app details including hosting info and associated clients."
      def self.tool_category = "database"
      def self.tool_risk_level = "low"

      def self.tool_input_schema
        {
          type: "object",
          properties: {
            query: { type: "string", description: "Search by app name" },
            included_only: { type: "boolean", description: "Only show billing-included apps (default true)" },
            limit: { type: "integer", description: "Max results (default 50)" }
          }
        }
      end

      def call(input_data)
        scope = ::App.all

        scope = scope.search(input_data["query"]) if input_data["query"].present?
        scope = scope.included if input_data.fetch("included_only", true)

        limit = (input_data["limit"] || 50).to_i.clamp(1, 200)
        apps = scope.order(:name).limit(limit)

        {
          apps: apps.map { |a|
            {
              id: a.id,
              name: a.name,
              full_name: a.full_name,
              included: a.included,
              has_render: a.has_render_service?,
              render_plan: a.render_plan,
              render_service_type: a.render_service_type,
              monthly_cost: a.total_monthly_cost.to_f,
              client_names: a.clients.map(&:name)
            }
          },
          total_count: scope.count
        }
      rescue => e
        { error: e.message }
      end
    end
  end
end
