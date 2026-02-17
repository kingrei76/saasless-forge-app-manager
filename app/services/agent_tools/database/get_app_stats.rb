# frozen_string_literal: true

module AgentTools
  module Database
    class GetAppStats < AgentTools::Base
      def self.tool_name = "Get App Stats"
      def self.tool_description = "Get aggregate dashboard statistics: client count, project counts by status, invoice totals, app count, and recent activity summary."
      def self.tool_category = "database"
      def self.tool_risk_level = "low"

      def self.tool_input_schema
        { type: "object", properties: {} }
      end

      def call(_input_data)
        {
          clients: {
            total: Client.count,
            with_stripe: Client.where.not(stripe_customer_id: [nil, ""]).count,
            with_subscriptions: Client.where.not(stripe_subscription_id: [nil, ""]).count
          },
          projects: {
            total: Project.count,
            active: Project.active.count,
            by_status: Project.group(:status).count,
            by_stage: Project.group(:stage).count
          },
          invoices: {
            total: Invoice.count,
            by_status: Invoice.group(:status).count,
            total_revenue: Invoice.where(status: "paid").sum(:total).to_f,
            outstanding: Invoice.where(status: %w[sent overdue]).sum(:total).to_f,
            this_month: Invoice.where("created_at >= ?", Date.current.beginning_of_month).count
          },
          apps: {
            total: App.count,
            included: App.included.count,
            with_render: App.with_render.count
          },
          agents: {
            total: Agent.count,
            active: Agent.where(status: "active").count,
            executions_today: AgentExecution.where("created_at >= ?", Date.current.beginning_of_day).count,
            open_alerts: AgentAlert.open_alerts.count
          },
          generated_at: Time.current.iso8601
        }
      rescue => e
        { error: e.message }
      end
    end
  end
end
