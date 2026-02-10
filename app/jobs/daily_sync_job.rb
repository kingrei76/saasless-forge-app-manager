class DailySyncJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "[DailySync] Starting daily sync for all GitHub accounts"

    synced_count = 0
    failed_count = 0

    GithubAccount.find_each do |account|
      GithubAccountSyncJob.perform_later(account.id)
      synced_count += 1
    rescue StandardError => e
      Rails.logger.error "[DailySync] Failed to enqueue sync for account #{account.id}: #{e.message}"
      failed_count += 1
    end

    Rails.logger.info "[DailySync] Enqueued #{synced_count} account syncs (#{failed_count} failures)"
  end
end
