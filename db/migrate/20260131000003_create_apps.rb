class CreateApps < ActiveRecord::Migration[7.2]
  def change
    create_table :apps do |t|
      t.references :github_account, null: false, foreign_key: true
      t.string :github_repo_id
      t.string :name
      t.string :full_name
      t.string :url
      t.text :description
      t.string :default_branch
      t.string :language
      t.string :latest_commit_sha
      t.string :latest_commit_message
      t.datetime :latest_commit_at
      t.boolean :included, default: true
      t.string :status
      t.jsonb :tags, default: []
      t.jsonb :github_metadata, default: {}

      t.timestamps
    end

    add_index :apps, :github_repo_id, unique: true
  end
end
