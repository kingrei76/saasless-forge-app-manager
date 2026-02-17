# frozen_string_literal: true

module AgentTools
  module Stripe
    class CheckPaymentStatus < AgentTools::Base
      def self.tool_name = "Check Payment Status"
      def self.tool_description = "Check the current payment status of an invoice, including Stripe sync. Returns local and Stripe-side status."
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

      def call(input_data)
        invoice = Invoice.includes(:client).find(input_data["invoice_id"])

        result = {
          invoice_id: invoice.id,
          client_name: invoice.client.name,
          local_status: invoice.status,
          total: invoice.total.to_f,
          due_date: invoice.due_date&.to_s,
          paid_at: invoice.paid_at&.iso8601,
          stripe_invoice_id: invoice.stripe_invoice_id,
          stripe_status: invoice.stripe_status,
          hosted_invoice_url: invoice.stripe_hosted_invoice_url
        }

        # If there's a Stripe invoice, fetch live status
        if invoice.stripe_invoice_id.present?
          begin
            configure_stripe!
            stripe_inv = ::Stripe::Invoice.retrieve(invoice.stripe_invoice_id)
            result[:stripe_live_status] = stripe_inv.status
            result[:stripe_amount_due] = stripe_inv.amount_due / 100.0
            result[:stripe_amount_paid] = stripe_inv.amount_paid / 100.0
            result[:stripe_amount_remaining] = stripe_inv.amount_remaining / 100.0
          rescue => e
            result[:stripe_error] = e.message
          end
        end

        result
      rescue ActiveRecord::RecordNotFound
        { error: "Invoice not found with ID #{input_data["invoice_id"]}" }
      rescue => e
        { error: e.message }
      end

      private

      def configure_stripe!
        ::Stripe.api_key = Setting["stripe_api_key"] || ENV["STRIPE_API_KEY"]
      end
    end
  end
end
