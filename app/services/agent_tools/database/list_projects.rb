# frozen_string_literal: true

module AgentTools
  module Database
    class ListProjects < AgentTools::Base
      def self.tool_name = "List Projects"
      def self.tool_description = "List projects with optional filtering by client, status, or stage. Returns project details including hours and billing info."
      def self.tool_category = "database"
      def self.tool_risk_level = "low"

      def self.tool_input_schema
        {
          type: "object",
          properties: {
            client_id: { type: "integer", description: "Filter by client ID" },
            status: { type: "string", enum: %w[active on_hold completed cancelled], description: "Filter by status" },
            stage: { type: "string", description: "Filter by stage" },
            limit: { type: "integer", description: "Max results (default 50)" }
          }
        }
      end

      def call(input_data)
        scope = Project.includes(:client, :assignee)

        scope = scope.where(client_id: input_data["client_id"]) if input_data["client_id"].present?
        scope = scope.by_status(input_data["status"]) if input_data["status"].present?
        scope = scope.by_stage(input_data["stage"]) if input_data["stage"].present?

        limit = (input_data["limit"] || 50).to_i.clamp(1, 200)
        projects = scope.order(created_at: :desc).limit(limit)

        {
          projects: projects.map { |p|
            {
              id: p.id,
              title: p.title,
              client_name: p.client.name,
              assignee: p.assignee&.name,
              status: p.status,
              stage: p.stage,
              estimated_hours: p.estimated_hours.to_f,
              actual_hours: p.actual_hours.to_f,
              hours_variance: p.hours_variance.to_f,
              created_at: p.created_at.iso8601
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
