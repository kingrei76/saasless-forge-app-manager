class CreateGithubAccounts < ActiveRecord::Migration[7.2]
  def change
    create_table :github_accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :account_name, null: false
      t.text :access_token
      t.string :label
      t.datetime :last_synced_at

      t.timestamps
    end
  end
end
