# frozen_string_literal: true

module AgentTools
  module Infrastructure
    class GetServiceStatus < AgentTools::Base
      def self.tool_name = "Get Service Status"
      def self.tool_description = "Get the current status and details of Render services, including deploy status, plan, and region. Can query a specific app or all tracked services."
      def self.tool_category = "api"
      def self.tool_risk_level = "low"

      def self.tool_input_schema
        {
          type: "object",
          properties: {
            app_id: { type: "integer", description: "App ID to check (omit for all tracked services)" }
          }
        }
      end

      def call(input_data)
        if input_data["app_id"].present?
          app = App.find(input_data["app_id"])
          return { error: "App '#{app.name}' has no Render service configured" } unless app.has_render_service?

          fetch_service_status(app)
        else
          apps = App.with_render.included
          {
            services: apps.map { |a| fetch_service_status(a) },
            total_count: apps.count
          }
        end
      rescue ActiveRecord::RecordNotFound
        { error: "App not found with ID #{input_data["app_id"]}" }
      rescue => e
        { error: e.message }
      end

      private

      def fetch_service_status(app)
        result = {
          app_id: app.id,
          app_name: app.name,
          render_service_id: app.render_service_id,
          render_service_type: app.render_service_type,
          render_plan: app.render_plan
        }

        # Try fetching live status from Render API
        if app.render_service_id.present?
          begin
            api = RenderApiService.new
            service = api.get_service(app.render_service_id)
            if service
              result[:status] = service.dig("service", "suspended") == "not_suspended" ? "running" : "suspended"
              result[:deploy_status] = service.dig("service", "serviceDetails", "buildCommand") ? "configured" : "unknown"
              result[:region] = service.dig("service", "region")
              result[:updated_at] = service.dig("service", "updatedAt")
            end
          rescue => e
            result[:render_error] = e.message
          end
        end

        result
      end
    end
  end
end
