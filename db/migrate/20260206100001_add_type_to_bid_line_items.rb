class AddTypeToBidLineItems < ActiveRecord::Migration[7.2]
  def change
    add_column :bid_line_items, :line_item_type, :string, default: "development", null: false
    add_column :bid_line_items, :unit_cost, :decimal, precision: 10, scale: 2
    add_column :bid_line_items, :display_price, :decimal, precision: 10, scale: 2
    add_column :bid_line_items, :is_recurring, :boolean, default: false
    add_column :bid_line_items, :billing_frequency, :string

    add_index :bid_line_items, :line_item_type
  end
end
