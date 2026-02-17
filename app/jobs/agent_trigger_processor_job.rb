class AgentTriggerProcessorJob < ApplicationJob
  queue_as :default

  def perform
    scheduled_count = AgentTriggerService.process_scheduled_triggers
    data_count = AgentTriggerService.process_data_triggers

    if scheduled_count > 0 || data_count > 0
      Rails.logger.info("AgentTriggerProcessorJob: Fired #{scheduled_count} schedule triggers, #{data_count} data triggers")
    end
  rescue => e
    Rails.logger.error("AgentTriggerProcessorJob: #{e.message}")
    Rails.logger.error(e.backtrace.first(5).join("\n"))
  end
end
