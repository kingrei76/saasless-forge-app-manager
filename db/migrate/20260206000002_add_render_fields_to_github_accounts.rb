class AddRenderFieldsToGithubAccounts < ActiveRecord::Migration[7.2]
  def up
    add_column :github_accounts, :render_api_key, :text
    add_column :github_accounts, :render_owner_id, :string
    add_column :github_accounts, :render_last_synced_at, :datetime

    add_index :github_accounts, :render_owner_id

    # Migrate existing global Render API key to the first GitHub account
    existing_key = Setting.find_by(key: "render_api_key")&.value
    if existing_key.present?
      first_account = GithubAccount.order(:created_at).first
      if first_account
        first_account.update_column(:render_api_key, existing_key)
        puts "Migrated Render API key to GitHub account: #{first_account.account_name}"
      end
    end
  end

  def down
    remove_index :github_accounts, :render_owner_id
    remove_column :github_accounts, :render_last_synced_at
    remove_column :github_accounts, :render_owner_id
    remove_column :github_accounts, :render_api_key
  end
end
