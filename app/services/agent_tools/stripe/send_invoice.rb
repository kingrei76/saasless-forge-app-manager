# frozen_string_literal: true

module AgentTools
  module Stripe
    class SendInvoice < AgentTools::Base
      def self.tool_name = "Send Invoice"
      def self.tool_description = "Finalize and send an existing draft invoice via Stripe. The invoice must be in 'draft' status. This creates a Stripe invoice, adds line items, finalizes it, and sends the payment link to the client."
      def self.tool_category = "api"
      def self.tool_risk_level = "high"

      def self.tool_input_schema
        {
          type: "object",
          properties: {
            invoice_id: { type: "integer", description: "Invoice ID (must be in draft status)" }
          },
          required: ["invoice_id"]
        }
      end

      def call(input_data)
        invoice = Invoice.find(input_data["invoice_id"])

        unless invoice.status == "draft"
          return { error: "Invoice ##{invoice.id} is '#{invoice.status}', not 'draft'. Only draft invoices can be sent." }
        end

        service = StripeInvoiceService.new(invoice)
        stripe_invoice = service.create_and_send!

        {
          invoice_id: invoice.id,
          stripe_invoice_id: invoice.reload.stripe_invoice_id,
          status: invoice.status,
          stripe_status: invoice.stripe_status,
          hosted_invoice_url: invoice.stripe_hosted_invoice_url,
          total: invoice.total.to_f,
          message: "Invoice ##{invoice.id} sent to #{invoice.client.name} via Stripe."
        }
      rescue ActiveRecord::RecordNotFound
        { error: "Invoice not found with ID #{input_data["invoice_id"]}" }
      rescue => e
        { error: e.message }
      end
    end
  end
end
