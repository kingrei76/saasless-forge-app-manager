# frozen_string_literal: true

module AgentTools
  module Stripe
    class SyncBillingCycles < AgentTools::Base
      def self.tool_name = "Sync Billing Cycles"
      def self.tool_description = "Sync billing cycle information from Stripe for one or all clients. Updates billing anchor, billing day, and subscription data."
      def self.tool_category = "api"
      def self.tool_risk_level = "medium"

      def self.tool_input_schema
        {
          type: "object",
          properties: {
            client_id: { type: "integer", description: "Client ID (omit to sync all clients)" }
          }
        }
      end

      def call(input_data)
        service = StripeBillingCycleService.new

        if input_data["client_id"].present?
          client = Client.find(input_data["client_id"])
          results = {}
          service.sync_client(client, results)
          {
            client_id: client.id,
            client_name: client.name,
            billing_day: client.reload.billing_day_of_month,
            billing_anchor: client.billing_anchor&.iso8601,
            message: "Billing cycle synced for #{client.name}."
          }
        else
          results = service.sync_all_clients
          {
            synced: results[:synced],
            skipped: results[:skipped],
            errors: results[:errors],
            message: "Synced billing cycles for #{results[:synced]} clients."
          }
        end
      rescue ActiveRecord::RecordNotFound
        { error: "Client not found with ID #{input_data["client_id"]}" }
      rescue => e
        { error: e.message }
      end
    end
  end
end
