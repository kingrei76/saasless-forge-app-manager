class AddAiApiKeyToApps < ActiveRecord::Migration[7.2]
  def change
    add_column :apps, :ai_api_key, :string
    add_column :apps, :ai_api_provider, :string, default: "grok"
  end
end
