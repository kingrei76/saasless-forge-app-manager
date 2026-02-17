# frozen_string_literal: true

# Agent Framework Configuration
# ==============================
# This initializer configures the agent framework for this application.
# When installing on a new app, customize this file to register your
# app-specific events, integrations, and settings.
#
# The framework provides:
#   - Event Registry: tracks all events agents can trigger on
#   - Route Introspection: auto-discovers all API/webhook endpoints
#   - Model Introspection: auto-discovers data models and relationships
#   - Agent Configuration API: CRUD for agents, tools, triggers, goals
#   - Introspection API: agents can discover what the app offers
#
# Minimum setup for a new app:
#   1. Copy the agent models + migrations
#   2. Copy the agent controllers (api/ and admin/)
#   3. Copy the services (event_registry, route_introspector, model_introspector, agent_trigger_service)
#   4. Copy this initializer and customize the config block below
#   5. Add the routes from config/routes.rb (api namespace)
#   6. Run migrations

module AgentFramework
  class << self
    attr_accessor :config

    def configure
      self.config ||= default_config
      yield(config) if block_given?
    end

    def default_config
      {
        app_name: Rails.application.class.respond_to?(:module_parent_name) ?
                    Rails.application.class.module_parent_name.titleize :
                    "Rails Application",
        # Which integrations to auto-register events for
        integrations: [],
        # Custom event categories to register
        custom_events: []
      }
    end
  end
end

# ---- Configure for this application ----

AgentFramework.configure do |config|
  config[:app_name] = "SaaSless Forge App Manager"

  # Register integrations that fire events.
  # Each integration name corresponds to a method on EventRegistry:
  #   "stripe" → EventRegistry.register_stripe_events!
  config[:integrations] = %w[stripe]
end

# ---- Register integration events ----

Rails.application.config.after_initialize do
  AgentFramework.config[:integrations].each do |integration|
    method_name = :"register_#{integration}_events!"
    if EventRegistry.respond_to?(method_name)
      EventRegistry.public_send(method_name)
      Rails.logger.info("AgentFramework: Registered #{integration} events")
    else
      Rails.logger.warn("AgentFramework: No event registration method for '#{integration}' (expected EventRegistry.#{method_name})")
    end
  end

  # ---- Register app-specific custom events ----
  # Uncomment and customize these for your app:
  #
  # EventRegistry.register(
  #   name: "orders.placed",
  #   category: "commerce",
  #   description: "Fired when a new order is placed.",
  #   data_schema: [
  #     { path: "order_id", type: "integer", description: "Order ID" },
  #     { path: "total", type: "float", description: "Order total" },
  #     { path: "customer_email", type: "string", description: "Customer email" }
  #   ]
  # )
  #
  # EventRegistry.register(
  #   name: "deploy.completed",
  #   category: "infrastructure",
  #   description: "Fired when a deployment completes.",
  #   data_schema: [
  #     { path: "service_name", type: "string", description: "Service name" },
  #     { path: "status", type: "string", description: "Deploy status" },
  #     { path: "commit_sha", type: "string", description: "Git commit SHA" }
  #   ]
  # )

  event_count = EventRegistry.all_events.size
  category_count = EventRegistry.categories.size
  Rails.logger.info("AgentFramework: #{event_count} events registered across #{category_count} categories")

  # ---- Tool Discovery: sync tool definitions on boot in development ----
  if Rails.env.development?
    begin
      result = ToolRegistryService.sync!
      Rails.logger.info("AgentFramework: Tool sync on boot - #{result[:synced]} synced, #{result[:total]} total")
    rescue => e
      Rails.logger.warn("AgentFramework: Tool sync on boot failed - #{e.message}")
    end
  end
end
