class AddAppIdToApiUsageLogs < ActiveRecord::Migration[7.2]
  def change
    add_reference :api_usage_logs, :app, foreign_key: true, null: true
    add_index :api_usage_logs, [:app_id, :created_at]
  end
end
