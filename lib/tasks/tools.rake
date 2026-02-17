# frozen_string_literal: true

namespace :tools do
  desc "Sync tool definitions from AgentTools classes into the database"
  task sync: :environment do
    puts "Syncing tool definitions..."
    result = ToolRegistryService.sync!
    puts "Done: #{result[:synced]} synced, #{result[:skipped]} unchanged, #{result[:total]} total discovered"
  end

  desc "Attach all active tool definitions to the agent-builder agent"
  task attach_to_builder: :environment do
    builder = Agent.find_by(slug: "agent-builder")
    unless builder
      puts "Error: No agent with slug 'agent-builder' found. Run `rake agents:seed_builder` first."
      exit 1
    end

    tools = ToolDefinition.active
    attached = 0

    tools.each do |tool|
      unless builder.agent_tools.exists?(tool_definition: tool)
        builder.agent_tools.create!(
          tool_definition: tool,
          enabled: true,
          requires_approval: tool.risk_level.in?(%w[high critical])
        )
        attached += 1
      end
    end

    puts "Attached #{attached} new tools to agent-builder (#{builder.agent_tools.count} total)"
  end
end
