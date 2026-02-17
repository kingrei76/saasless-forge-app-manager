# frozen_string_literal: true

module AgentTools
  module Stripe
    class ListClientBilling < AgentTools::Base
      def self.tool_name = "List Client Billing"
      def self.tool_description = "Get billing overview for a client: billing cycle, recent invoices, payment method status, and recurring invoice info."
      def self.tool_category = "api"
      def self.tool_risk_level = "low"

      def self.tool_input_schema
        {
          type: "object",
          properties: {
            client_id: { type: "integer", description: "Client ID" }
          },
          required: ["client_id"]
        }
      end

      def call(input_data)
        client = Client.includes(:invoices, :recurring_invoice).find(input_data["client_id"])

        period = client.current_billing_period
        recent_invoices = client.invoices.visible.order(created_at: :desc).limit(10)

        {
          client: {
            id: client.id,
            name: client.name,
            email: client.email,
            stripe_customer_id: client.stripe_customer_id,
            has_stripe_subscription: client.has_stripe_subscription?,
            collection_method: client.collection_method,
            has_payment_method: client.stripe_default_payment_method_id.present?,
            markup_percentage: client.effective_markup
          },
          billing_cycle: period ? { start: period[0].to_s, end: period[1].to_s } : nil,
          billing_day: client.billing_day_of_month,
          cycle_progress: client.billing_cycle_progress_percentage,
          recurring_invoice: client.recurring_invoice ? {
            id: client.recurring_invoice.id,
            status: client.recurring_invoice.status,
            next_billing_date: client.recurring_invoice.next_billing_date&.to_s,
            last_billed_date: client.recurring_invoice.last_billed_date&.to_s
          } : nil,
          recent_invoices: recent_invoices.map { |inv|
            {
              id: inv.id,
              status: inv.status,
              total: inv.total.to_f,
              payment_type: inv.payment_type,
              created_at: inv.created_at.iso8601
            }
          }
        }
      rescue ActiveRecord::RecordNotFound
        { error: "Client not found with ID #{input_data["client_id"]}" }
      rescue => e
        { error: e.message }
      end
    end
  end
end
