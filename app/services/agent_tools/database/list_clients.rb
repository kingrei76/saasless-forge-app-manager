# frozen_string_literal: true

module AgentTools
  module Database
    class ListClients < AgentTools::Base
      def self.tool_name = "List Clients"
      def self.tool_description = "List all clients with optional filtering by name, billing status, or active status. Returns client details and billing summary."
      def self.tool_category = "database"
      def self.tool_risk_level = "low"

      def self.tool_input_schema
        {
          type: "object",
          properties: {
            name: { type: "string", description: "Filter by client name (partial match)" },
            has_stripe: { type: "boolean", description: "Filter to only clients with Stripe setup" },
            limit: { type: "integer", description: "Max results (default 50)" }
          }
        }
      end

      def call(input_data)
        scope = Client.includes(:invoices, :projects)

        if input_data["name"].present?
          scope = scope.where("clients.name ILIKE ?", "%#{input_data["name"]}%")
        end

        if input_data["has_stripe"] == true
          scope = scope.where.not(stripe_customer_id: [nil, ""])
        end

        limit = (input_data["limit"] || 50).to_i.clamp(1, 200)
        clients = scope.order(:name).limit(limit)

        {
          clients: clients.map { |c|
            {
              id: c.id,
              name: c.name,
              email: c.email,
              has_stripe: c.stripe_customer_id.present?,
              has_subscription: c.has_stripe_subscription?,
              collection_method: c.collection_method,
              invoice_count: c.invoices.size,
              project_count: c.projects.size,
              billing_day: c.billing_day_of_month
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
