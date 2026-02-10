class AddInternalMetadataToBids < ActiveRecord::Migration[7.2]
  def change
    # Work category for line items (planning, dev, testing, etc.)
    add_column :bid_line_items, :work_category, :string
    add_index :bid_line_items, :work_category

    # Internal notes on the bid itself (never shown to customer)
    add_column :bids, :internal_notes, :text
  end
end
