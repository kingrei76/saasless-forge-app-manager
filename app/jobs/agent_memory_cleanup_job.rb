class AgentMemoryCleanupJob < ApplicationJob
  queue_as :default

  def perform
    count = AgentMemoryService.purge_all_expired!
    Rails.logger.info("AgentMemoryCleanupJob: Purged #{count} expired memories") if count > 0
  end
end
