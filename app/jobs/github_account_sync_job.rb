class GithubAccountSyncJob < ApplicationJob
  queue_as :default

  def perform(github_account_id)
    account = GithubAccount.find_by(id: github_account_id)
    return unless account

    Rails.logger.info "[GithubAccountSync] Syncing GitHub account #{account.id} (#{account.display_name})"

    # Sync GitHub repos
    result = GithubSyncService.new(account).sync!
    Rails.logger.info "[GithubAccountSync] GitHub sync complete: #{result[:synced]} synced, #{result[:skipped]} skipped"

    # Also sync Render if configured
    if account.render_configured?
      Rails.logger.info "[GithubAccountSync] Syncing Render services for account #{account.id}"
      RenderSyncService.new(github_account: account).sync_render_services
      account.update!(render_last_synced_at: Time.current)
      Rails.logger.info "[GithubAccountSync] Render sync complete for account #{account.id}"
    end
  rescue StandardError => e
    Rails.logger.error "[GithubAccountSync] Sync failed for GitHub account #{github_account_id}: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
  end
end
