# frozen_string_literal: true

class ToolDiscoverySyncJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info("ToolDiscoverySyncJob: Starting full tool discovery sync")

    result = ToolRegistryService.full_sync!

    log_results(result)
    create_alert_if_needed(result[:changes])

    Rails.logger.info("ToolDiscoverySyncJob: Complete")
  rescue => e
    Rails.logger.error("ToolDiscoverySyncJob: Failed - #{e.message}")
    Rails.logger.error(e.backtrace.first(5).join("\n"))
  end

  private

  def log_results(result)
    sync = result[:sync]
    discovery = result[:discovery]
    changes = result[:changes]

    Rails.logger.info(
      "ToolDiscoverySyncJob: Sync=#{sync[:synced]} synced/#{sync[:skipped]} unchanged, " \
      "Discovery=#{discovery[:created]} created/#{discovery[:skipped]} skipped, " \
      "Changes=#{changes[:status]}"
    )

    if changes[:changes]&.any?
      changes[:changes].each do |change|
        Rails.logger.info("ToolDiscoverySyncJob: Change detected - #{change[:type]}: #{change[:items]&.join(", ") || change[:model]}")
      end
    end
  end

  def create_alert_if_needed(change_result)
    return unless change_result[:status] == "changed"

    significant_changes = (change_result[:changes] || []).select { |c|
      c[:type].in?(%w[new_models removed_models new_api_routes])
    }

    return if significant_changes.empty?

    description = significant_changes.map { |c|
      case c[:type]
      when "new_models"
        "New models detected: #{c[:items].join(", ")}"
      when "removed_models"
        "Models removed: #{c[:items].join(", ")}"
      when "new_api_routes"
        "New API routes: #{c[:items].join(", ")}"
      end
    }.join("\n")

    AgentAlert.create!(
      alert_type: "anomaly",
      severity: "info",
      title: "Schema changes detected by tool discovery",
      description: description,
      context: { changes: significant_changes },
      status: "open"
    )

    Rails.logger.info("ToolDiscoverySyncJob: Created alert for schema changes")
  end
end
