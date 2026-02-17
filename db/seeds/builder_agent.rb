# Seed the Agent Builder agent with all 16 built-in tools
#
# Usage:
#   rails runner db/seeds/builder_agent.rb
#   rake agents:seed_builder

BUILDER_SYSTEM_PROMPT = <<~PROMPT
  You are the Agent Builder — an AI assistant that helps users create and configure agents in SaaSless Forge.

  ## How to work

  1. **Introspect first**: Always call `introspect_app` at the start of a conversation to discover what the application offers (events, tools, models, routes, integrations).

  2. **Explain before acting**: Before making any changes, explain what you're going to do and why. When you propose creating or modifying an agent, describe the full configuration clearly.

  3. **Guide step by step**: Walk users through agent configuration one piece at a time:
     - Start with the agent's purpose and name
     - Set up the system prompt
     - Attach relevant tools
     - Configure triggers (what fires the agent)
     - Define goals (what success looks like)
     - Set up handoffs if needed (agent chaining)

  4. **Use context**: When editing an existing agent, review its current configuration with `get_agent_detail` before suggesting changes.

  5. **Be specific**: When suggesting tools, triggers, or events, reference actual items from the introspection results — don't guess or fabricate names.

  6. **Approval-based changes**: All builder actions (create_agent, update_agent, attach_tool, etc.) require user approval. Present what you want to do clearly so the user can make an informed decision.

  ## What you can do

  - **Discover**: Introspect the app to find available events, tools, routes, models, and existing agents
  - **Create agents**: Set up new agents with names, categories, system prompts, and configurations
  - **Configure tools**: Attach/detach tool definitions to agents
  - **Set up triggers**: Add event-based, schedule-based, webhook, or dependency triggers
  - **Define goals**: Add success criteria and goals for agents
  - **Create handoffs**: Set up agent-to-agent execution chains
  - **Execute agents**: Trigger test runs of configured agents

  ## Response style

  - Be concise but thorough
  - Use bullet points for lists
  - Show configuration details in a structured format
  - After making changes, summarize what was done
PROMPT

# All 16 built-in tool slugs and their properties
# NOTE: slugs MUST match Python tool names exactly (underscores, not hyphens)
# because LanggraphClient sends td.slug as the tool name to the Python service.
BUILTIN_TOOLS = [
  # Introspection tools (no approval needed)
  { slug: "introspect_app",         name: "Introspect App",             category: "api", risk_level: "low",  requires_approval: false,
    description: "Get a complete overview of the host application including available events, tools, agents, API routes, data models, and service integrations." },
  { slug: "list_events",            name: "List Events",                category: "api", risk_level: "low",  requires_approval: false,
    description: "List all events the application can fire, with their categories and data field schemas." },
  { slug: "list_available_tools",   name: "List Available Tools",       category: "api", risk_level: "low",  requires_approval: false,
    description: "List all active tool definitions in the application with their categories, risk levels, and schemas." },
  { slug: "list_agents",            name: "List Agents",                category: "api", risk_level: "low",  requires_approval: false,
    description: "List all agents in the application with their status, category, mode, and tool/trigger/goal counts." },
  { slug: "list_routes",            name: "List Routes",                category: "api", risk_level: "low",  requires_approval: false,
    description: "List all API endpoints, webhook URLs, and actionable routes in the application." },
  { slug: "list_models",            name: "List Models",                category: "api", risk_level: "low",  requires_approval: false,
    description: "List all data models with their columns, associations, and validations." },
  { slug: "get_trigger_schema",     name: "Get Trigger Schema",         category: "api", risk_level: "low",  requires_approval: false,
    description: "Get the data field schema for a specific trigger context. Returns available field paths for building conditions." },

  # Agent builder tools (approval required)
  { slug: "get_agent_detail",       name: "Get Agent Detail",           category: "api", risk_level: "low",  requires_approval: false,
    description: "Get detailed information about a specific agent including its tools, triggers, goals, and handoffs." },
  { slug: "create_agent",           name: "Create Agent",               category: "api", risk_level: "medium", requires_approval: true,
    description: "Create a new agent with the specified configuration (name, category, system prompt, model, etc.)." },
  { slug: "update_agent",           name: "Update Agent",               category: "api", risk_level: "medium", requires_approval: true,
    description: "Update an existing agent's configuration fields." },
  { slug: "attach_tool_to_agent",   name: "Attach Tool to Agent",       category: "api", risk_level: "medium", requires_approval: true,
    description: "Attach a tool definition to an agent so the agent can use it during execution." },
  { slug: "detach_tool_from_agent", name: "Detach Tool from Agent",     category: "api", risk_level: "medium", requires_approval: true,
    description: "Remove a tool attachment from an agent." },
  { slug: "add_trigger_to_agent",   name: "Add Trigger to Agent",       category: "api", risk_level: "medium", requires_approval: true,
    description: "Add a trigger (event, schedule, webhook, data, or dependency) to automatically fire an agent." },
  { slug: "add_goal_to_agent",      name: "Add Goal to Agent",          category: "api", risk_level: "medium", requires_approval: true,
    description: "Add a goal with success criteria to define what success looks like for an agent." },
  { slug: "add_handoff_to_agent",   name: "Add Handoff to Agent",       category: "api", risk_level: "medium", requires_approval: true,
    description: "Add a handoff that transfers execution to another agent upon completion." },
  { slug: "execute_agent",          name: "Execute Agent",              category: "api", risk_level: "high", requires_approval: true,
    description: "Trigger an agent execution. The agent must be in 'active' status." }
].freeze

def seed_builder_agent!
  puts "Seeding Agent Builder agent..."

  # Find or create the builder agent
  builder = Agent.find_or_initialize_by(slug: "agent-builder")
  builder.assign_attributes(
    name: "Agent Builder",
    description: "An AI assistant that helps you create and configure agents through natural language conversation. It can introspect the application, discover available tools and events, and build agent configurations step by step.",
    category: "orchestrator",
    status: "active",
    mode: "live",
    temperature: 0.7,
    max_iterations: 30,
    system_prompt: BUILDER_SYSTEM_PROMPT
  )

  # Assign created_by to first admin user if not set
  builder.created_by ||= User.find_by(admin: true)

  builder.save!
  puts "  Agent Builder agent: #{builder.id} (#{builder.slug})"

  # Ensure all tool definitions exist
  BUILTIN_TOOLS.each do |tool_attrs|
    td = ToolDefinition.find_or_initialize_by(slug: tool_attrs[:slug])
    td.assign_attributes(
      name: tool_attrs[:name],
      description: tool_attrs[:description],
      category: tool_attrs[:category],
      risk_level: tool_attrs[:risk_level],
      status: "active",
      metadata: (td.metadata || {}).merge("builtin" => true)
    )
    td.save!

    # Attach to builder agent if not already attached
    at = AgentTool.find_or_initialize_by(agent: builder, tool_definition: td)
    at.assign_attributes(
      enabled: true,
      requires_approval: tool_attrs[:requires_approval],
      position: BUILTIN_TOOLS.index(tool_attrs)
    )
    at.save!
  end

  puts "  Attached #{builder.agent_tools.count} tools"
  puts "Agent Builder seed complete."

  builder
end

seed_builder_agent! if __FILE__ == $0 || defined?(Rails::Command)
