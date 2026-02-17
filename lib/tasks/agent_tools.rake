namespace :agent_tools do
  desc "Sync tool definitions from AgentTools classes to the database"
  task sync: :environment do
    result = ToolRegistryService.sync!
    puts "Tool Registry Sync Complete:"
    puts "  Synced: #{result[:synced]}"
    puts "  Skipped: #{result[:skipped]}"
    puts "  Total discovered: #{result[:total]}"
  end
end
