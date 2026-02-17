# frozen_string_literal: true

module AgentTools
  module Stripe
    class SetupPaymentMethod < AgentTools::Base
      def self.tool_name = "Setup Payment Method"
      def self.tool_description = "Generate a Stripe Checkout session URL for a client to set up their payment method. Returns a URL the client can visit to add their card."
      def self.tool_category = "api"
      def self.tool_risk_level = "medium"

      def self.tool_input_schema
        {
          type: "object",
          properties: {
            client_id: { type: "integer", description: "Client ID" },
            success_url: { type: "string", description: "URL to redirect after success (optional)" },
            cancel_url: { type: "string", description: "URL to redirect on cancel (optional)" }
          },
          required: ["client_id"]
        }
      end

      def call(input_data)
        client = Client.find(input_data["client_id"])

        base_url = Setting["app_base_url"] || "http://localhost:3000"
        success_url = input_data["success_url"] || "#{base_url}/admin/clients/#{client.id}"
        cancel_url = input_data["cancel_url"] || "#{base_url}/admin/clients/#{client.id}"

        service = StripePaymentMethodService.new(client)
        session = service.create_setup_session(success_url: success_url, cancel_url: cancel_url)

        {
          client_id: client.id,
          client_name: client.name,
          checkout_url: session.url,
          session_id: session.id,
          message: "Send this URL to #{client.name} to set up their payment method: #{session.url}"
        }
      rescue ActiveRecord::RecordNotFound
        { error: "Client not found with ID #{input_data["client_id"]}" }
      rescue => e
        { error: e.message }
      end
    end
  end
end
