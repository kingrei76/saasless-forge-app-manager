# frozen_string_literal: true

module AgentTools
  module Stripe
    class CreateInvoice < AgentTools::Base
      def self.tool_name = "Create Invoice"
      def self.tool_description = "Create a new draft invoice for a client. Requires client ID and line items. Does NOT send the invoice — use 'Send Invoice' for that."
      def self.tool_category = "api"
      def self.tool_risk_level = "high"

      def self.tool_input_schema
        {
          type: "object",
          properties: {
            client_id: { type: "integer", description: "Client ID" },
            payment_type: { type: "string", enum: %w[deposit final infrastructure full], description: "Payment type" },
            period_start: { type: "string", description: "Billing period start (YYYY-MM-DD)" },
            period_end: { type: "string", description: "Billing period end (YYYY-MM-DD)" },
            line_items: {
              type: "array",
              description: "Invoice line items",
              items: {
                type: "object",
                properties: {
                  description: { type: "string" },
                  quantity: { type: "number", description: "Quantity (default 1)" },
                  unit_price: { type: "number", description: "Unit price in dollars" }
                },
                required: %w[description unit_price]
              }
            },
            project_id: { type: "integer", description: "Optional project ID to associate" }
          },
          required: %w[client_id payment_type line_items]
        }
      end

      def call(input_data)
        client = Client.find(input_data["client_id"])

        invoice = Invoice.new(
          client: client,
          status: "draft",
          invoice_type: "cost_based",
          payment_type: input_data["payment_type"],
          period_start: input_data["period_start"] ? Date.parse(input_data["period_start"]) : nil,
          period_end: input_data["period_end"] ? Date.parse(input_data["period_end"]) : nil,
          project_id: input_data["project_id"],
          collection_method: client.collection_method || "send_invoice"
        )

        input_data["line_items"].each do |li|
          invoice.line_items.build(
            description: li["description"],
            quantity: li["quantity"] || 1,
            unit_price: li["unit_price"]
          )
        end

        invoice.save!
        invoice.recalculate_totals!

        {
          invoice_id: invoice.id,
          status: invoice.status,
          total: invoice.total.to_f,
          line_item_count: invoice.line_items.count,
          message: "Invoice ##{invoice.id} created as draft for #{client.name}. Use 'Send Invoice' to finalize and send via Stripe."
        }
      rescue ActiveRecord::RecordNotFound => e
        { error: "Client not found with ID #{input_data["client_id"]}" }
      rescue => e
        { error: e.message }
      end
    end
  end
end
