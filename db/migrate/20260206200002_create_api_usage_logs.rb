class CreateApiUsageLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :api_usage_logs do |t|
      t.string :provider, null: false
      t.string :model, null: false
      t.string :operation
      t.integer :input_tokens
      t.integer :output_tokens
      t.decimal :estimated_cost, precision: 10, scale: 6
      t.references :trackable, polymorphic: true
      t.timestamps
    end

    add_index :api_usage_logs, :provider
    add_index :api_usage_logs, [:provider, :created_at]
  end
end
