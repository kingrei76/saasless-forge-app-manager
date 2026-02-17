class Api::IntrospectionController < ApplicationController
  skip_before_action :verify_authenticity_token

  # GET /api/introspection — full app overview (everything an agent needs to understand the app)
  def index
    render json: {
      app: app_info,
      events: event_list,
      tools: tool_list,
      agents: agent_list,
      routes: route_info,
      models: model_info,
      enums: enum_info,
      webhooks: webhook_info,
      service_integrations: service_integrations,
      api_guide: api_guide
    }
  end

  # GET /api/introspection/events
  def events
    render json: { events: event_list, categories: EventRegistry.categories }
  end

  # GET /api/introspection/tools
  def tools
    render json: { tools: tool_list }
  end

  # GET /api/introspection/agents
  def agents
    render json: { agents: agent_list }
  end

  # GET /api/introspection/routes
  def routes
    render json: RouteIntrospector.discover
  end

  # GET /api/introspection/models
  def models
    render json: ModelIntrospector.discover
  end

  private

  def app_info
    {
      name: AgentFramework.config[:app_name],
      environment: Rails.env,
      ruby_version: RUBY_VERSION,
      rails_version: Rails::VERSION::STRING,
      base_url: Setting[:app_base_url].presence || ENV["APP_BASE_URL"] || request.base_url,
      framework_version: "1.0.0"
    }
  end

  def event_list
    EventRegistry.all_events.map do |e|
      {
        name: e.name,
        category: e.category,
        description: e.description,
        fields: e.data_schema
      }
    end
  end

  def tool_list
    ToolDefinition.active.order(:name).map do |td|
      {
        id: td.id,
        name: td.name,
        slug: td.slug,
        category: td.category,
        risk_level: td.risk_level,
        description: td.try(:description),
        input_schema: td.try(:input_schema),
        output_schema: td.try(:output_schema),
        agent_count: td.agents.count
      }
    end
  end

  def agent_list
    Agent.order(:name).map do |a|
      {
        id: a.id,
        name: a.name,
        slug: a.slug,
        category: a.category,
        status: a.status,
        mode: a.mode,
        description: a.try(:description),
        tool_count: a.agent_tools.count,
        trigger_count: a.agent_triggers.count,
        goal_count: a.agent_goals.count,
        handoff_count: a.agent_handoffs.count
      }
    end
  end

  def route_info
    {
      api_endpoints: RouteIntrospector.api_endpoints,
      webhook_endpoints: RouteIntrospector.webhook_endpoints,
      actionable_routes: RouteIntrospector.actionable_routes,
      summary: RouteIntrospector.summary
    }
  end

  def model_info
    ModelIntrospector.model_map
  end

  def enum_info
    {
      trigger_types: AgentTrigger::TRIGGER_TYPES,
      agent_categories: Agent::CATEGORIES,
      agent_statuses: Agent::STATUSES,
      agent_modes: Agent::MODES,
      tool_categories: ToolDefinition::CATEGORIES,
      tool_risk_levels: ToolDefinition::RISK_LEVELS,
      schedule_presets: AgentTrigger::SCHEDULE_PRESETS,
      execution_statuses: AgentExecution::STATUSES,
      condition_operators: %w[equals not_equals greater_than less_than greater_than_or_equal
                              less_than_or_equal contains not_contains starts_with ends_with
                              exists not_exists in not_in matches]
    }
  end

  def webhook_info
    endpoints = RouteIntrospector.webhook_endpoints

    # Add dynamic trigger webhooks with agent context
    AgentTrigger.enabled.where(trigger_type: "webhook").where.not(webhook_token: nil).includes(:agent).each do |trigger|
      endpoints << {
        method: "POST",
        path: "/api/triggers/#{trigger.webhook_token}",
        controller: "api/trigger_webhooks",
        action: "create",
        description: "Trigger webhook for agent: #{trigger.agent.name}",
        agent_id: trigger.agent_id,
        webhook: true
      }
    end

    endpoints
  end

  def service_integrations
    integrations = []

    # Auto-detect Stripe
    if defined?(Stripe) && (Setting[:stripe_api_key].present? rescue false)
      integrations << {
        name: "Stripe",
        type: "payment_processor",
        webhook_path: "/webhooks/stripe",
        events: EventRegistry.events_for_category("stripe").map(&:name),
        status: "configured"
      }
    end

    # Auto-detect LangGraph service
    langgraph_url = Setting[:langgraph_service_url].presence || ENV["LANGGRAPH_SERVICE_URL"]
    if langgraph_url.present?
      integrations << {
        name: "LangGraph Service",
        type: "agent_executor",
        url: langgraph_url,
        callback_path: "/api/agent_callbacks",
        status: "configured"
      }
    end

    # Auto-detect Services Gateway
    gateway_url = Setting[:gateway_service_url].presence || ENV["GATEWAY_SERVICE_URL"]
    if gateway_url.present?
      integrations << {
        name: "Services Gateway",
        type: "llm_proxy",
        url: gateway_url,
        status: "configured"
      }
    end

    integrations
  end

  # Structured guide for agents/builders to understand how to use the APIs
  def api_guide
    {
      authentication: {
        method: "Bearer token",
        header: "Authorization: Bearer <api_token>",
        description: "Include the user's api_token in the Authorization header for all API requests."
      },
      configuration_api: {
        base_path: "/api/agents",
        operations: {
          list_agents: { method: "GET", path: "/api/agents" },
          get_agent: { method: "GET", path: "/api/agents/:id" },
          create_agent: { method: "POST", path: "/api/agents", body: "agent[name], agent[slug], agent[category], agent[status], agent[mode], agent[system_prompt], agent[description]" },
          update_agent: { method: "PATCH", path: "/api/agents/:id" },
          execute_agent: { method: "POST", path: "/api/agents/:id/execute", body: "input_data (JSON)" },
          attach_tool: { method: "POST", path: "/api/agents/:agent_id/tools", body: "tool_definition_id, enabled, requires_approval" },
          detach_tool: { method: "DELETE", path: "/api/agents/:agent_id/tools/:id" },
          add_trigger: { method: "POST", path: "/api/agents/:agent_id/triggers", body: "trigger[trigger_type], trigger[event_name], trigger[schedule], trigger[condition]" },
          remove_trigger: { method: "DELETE", path: "/api/agents/:agent_id/triggers/:id" },
          add_goal: { method: "POST", path: "/api/agents/:agent_id/goals", body: "goal[title], goal[description], goal[priority]" },
          remove_goal: { method: "DELETE", path: "/api/agents/:agent_id/goals/:id" },
          add_handoff: { method: "POST", path: "/api/agents/:agent_id/handoffs", body: "handoff[target_agent_id], handoff[enabled], handoff[priority]" },
          remove_handoff: { method: "DELETE", path: "/api/agents/:agent_id/handoffs/:id" }
        }
      },
      introspection_api: {
        base_path: "/api/introspection",
        operations: {
          full_overview: { method: "GET", path: "/api/introspection" },
          events: { method: "GET", path: "/api/introspection/events" },
          tools: { method: "GET", path: "/api/introspection/tools" },
          agents: { method: "GET", path: "/api/introspection/agents" },
          routes: { method: "GET", path: "/api/introspection/routes" },
          models: { method: "GET", path: "/api/introspection/models" }
        }
      },
      trigger_schemas_api: {
        path: "/api/trigger_schemas",
        description: "Returns field schemas for condition building",
        params: "context (event|data|webhook|dependency), event_name, tool_definition_id"
      }
    }
  end

end
