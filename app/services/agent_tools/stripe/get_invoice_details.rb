# frozen_string_literal: true

module AgentTools
  module Stripe
    class GetInvoiceDetails < AgentTools::Base
      def self.tool_name = "Get Invoice Details"
      def self.tool_description = "Get full details for a specific invoice including line items, payment info, and Stripe status."
      def self.tool_category = "api"
      def self.tool_risk_level = "low"

      def self.tool_input_schema
        {
          type: "object",
          properties: {
            invoice_id: { type: "integer", description: "Invoice ID" }
          },
          required: ["invoice_id"]
        }
      end

      def self.tool_output_schema
        {
          type: "object",
          properties: {
            invoice: { type: "object", description: "Full invoice details" }
          }
        }
      end

      def call(input_data)
        invoice = Invoice.includes(:client, :project, :line_items).find(input_data["invoice_id"])

        {
          invoice: {
            id: invoice.id,
            client: { id: invoice.client.id, name: invoice.client.name, email: invoice.client.email },
            project: invoice.project ? { id: invoice.project.id, title: invoice.project.title } : nil,
            status: invoice.status,
            invoice_type: invoice.invoice_type,
            payment_type: invoice.payment_type,
            total: invoice.total.to_f,
            subtotal: invoice.subtotal.to_f,
            period_start: invoice.period_start&.to_s,
            period_end: invoice.period_end&.to_s,
            due_date: invoice.due_date&.to_s,
            paid_at: invoice.paid_at&.iso8601,
            collection_method: invoice.collection_method,
            stripe_invoice_id: invoice.stripe_invoice_id,
            stripe_status: invoice.stripe_status,
            stripe_hosted_invoice_url: invoice.stripe_hosted_invoice_url,
            line_items: invoice.line_items.map { |li|
              { description: li.description, quantity: li.quantity.to_f, unit_price: li.unit_price.to_f, total: li.total.to_f }
            },
            created_at: invoice.created_at.iso8601
          }
        }
      rescue ActiveRecord::RecordNotFound
        { error: "Invoice not found with ID #{input_data["invoice_id"]}" }
      rescue => e
        { error: e.message }
      end
    end
  end
end
