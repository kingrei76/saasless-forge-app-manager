# frozen_string_literal: true

module AgentTools
  module Stripe
    class SearchInvoices < AgentTools::Base
      def self.tool_name = "Search Invoices"
      def self.tool_description = "Search invoices by client name, status, date range, or payment type. Returns a list of matching invoices with key details."
      def self.tool_category = "api"
      def self.tool_risk_level = "low"

      def self.tool_input_schema
        {
          type: "object",
          properties: {
            client_name: { type: "string", description: "Filter by client name (partial match)" },
            status: { type: "string", enum: Invoice::STATUSES, description: "Filter by invoice status" },
            payment_type: { type: "string", enum: Invoice::PAYMENT_TYPES, description: "Filter by payment type" },
            from_date: { type: "string", description: "Start date (YYYY-MM-DD)" },
            to_date: { type: "string", description: "End date (YYYY-MM-DD)" },
            limit: { type: "integer", description: "Max results (default 20)" }
          }
        }
      end

      def self.tool_output_schema
        {
          type: "object",
          properties: {
            invoices: { type: "array", description: "List of matching invoices" },
            total_count: { type: "integer" }
          }
        }
      end

      def call(input_data)
        scope = Invoice.includes(:client, :project).visible

        if input_data["client_name"].present?
          scope = scope.joins(:client).where("clients.name ILIKE ?", "%#{input_data["client_name"]}%")
        end

        scope = scope.by_status(input_data["status"]) if input_data["status"].present?
        scope = scope.where(payment_type: input_data["payment_type"]) if input_data["payment_type"].present?

        if input_data["from_date"].present?
          scope = scope.where("invoices.created_at >= ?", Date.parse(input_data["from_date"]))
        end
        if input_data["to_date"].present?
          scope = scope.where("invoices.created_at <= ?", Date.parse(input_data["to_date"]).end_of_day)
        end

        limit = (input_data["limit"] || 20).to_i.clamp(1, 100)
        invoices = scope.order(created_at: :desc).limit(limit)

        {
          invoices: invoices.map { |inv| serialize_invoice(inv) },
          total_count: scope.count
        }
      rescue => e
        { error: e.message }
      end

      private

      def serialize_invoice(inv)
        {
          id: inv.id,
          client_name: inv.client.name,
          status: inv.status,
          payment_type: inv.payment_type,
          total: inv.total.to_f,
          period: [inv.period_start&.to_s, inv.period_end&.to_s].compact.join(" - "),
          project: inv.project&.title,
          stripe_status: inv.stripe_status,
          created_at: inv.created_at.iso8601
        }
      end
    end
  end
end
