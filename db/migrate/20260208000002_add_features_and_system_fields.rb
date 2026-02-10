class AddFeaturesAndSystemFields < ActiveRecord::Migration[7.2]
  def change
    # Features list for customer-facing view (stored as JSON array)
    add_column :bids, :features_list, :jsonb, default: []

    # System cost fields for existing vs new systems
    add_column :bid_line_items, :is_new_system, :boolean, default: false
    add_column :bid_line_items, :system_category, :string
  end
end
