class GithubSyncService
  def initialize(github_account)
    @account = github_account
    @api = GithubApiService.new(access_token: @account.access_token)
    @target_org = Setting[:github_target_organization].presence
  end

  def sync!
    repos = @api.all_repos
    synced_count = 0
    skipped_count = 0
    filtered_count = 0

    repos.each do |repo_data|
      github_repo_id = repo_data["id"].to_s
      owner = repo_data.dig("owner", "login")

      # Filter by target organization if configured
      if @target_org && owner&.downcase != @target_org.downcase
        filtered_count += 1
        next
      end

      # Check if this repo already exists (globally, not just for this account)
      existing_app = App.find_by(github_repo_id: github_repo_id)

      if existing_app && existing_app.github_account_id != @account.id
        # Repo belongs to another account, skip it
        skipped_count += 1
        next
      end

      # Find or create for this account
      app = existing_app || @account.apps.build(github_repo_id: github_repo_id)

      app.assign_attributes(
        name: repo_data["name"],
        full_name: repo_data["full_name"],
        url: repo_data["html_url"],
        description: repo_data["description"],
        default_branch: repo_data["default_branch"],
        language: repo_data["language"],
        github_owner: owner,
        github_metadata: {
          private: repo_data["private"],
          fork: repo_data["fork"],
          archived: repo_data["archived"],
          stars: repo_data["stargazers_count"],
          forks: repo_data["forks_count"],
          updated_at: repo_data["updated_at"]
        }
      )

      # Fetch latest commit
      if repo_data["full_name"]
        repo_owner, repo_name = repo_data["full_name"].split("/")
        commit = @api.latest_commit(
          owner: repo_owner,
          repo: repo_name,
          branch: repo_data["default_branch"] || "main"
        )

        if commit
          app.latest_commit_sha = commit["sha"]
          app.latest_commit_message = commit.dig("commit", "message")&.truncate(255)
          app.latest_commit_at = commit.dig("commit", "committer", "date")
        end
      end

      app.save!
      synced_count += 1
    end

    # Exclude existing apps from this account that are outside the target org
    excluded_count = 0
    if @target_org
      outside_apps = @account.apps.where.not(github_owner: nil)
                              .where.not("LOWER(github_owner) = ?", @target_org.downcase)
                              .where(included: true)
      excluded_count = outside_apps.count
      outside_apps.update_all(included: false) if excluded_count > 0
    end

    @account.update!(last_synced_at: Time.current)
    { synced: synced_count, skipped: skipped_count, filtered: filtered_count, excluded: excluded_count, total_repos: repos.size }
  rescue StandardError => e
    Rails.logger.error("GitHub sync failed for account #{@account.id}: #{e.message}")
    raise
  end
end
