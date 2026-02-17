class AddGithubOwnerToApps < ActiveRecord::Migration[7.2]
  def change
    add_column :apps, :github_owner, :string
    add_index :apps, :github_owner
  end
end
