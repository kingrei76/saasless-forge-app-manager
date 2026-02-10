class RenameEstimatesToBids < ActiveRecord::Migration[7.2]
  def change
    rename_table :estimates, :bids
    rename_table :estimate_line_items, :bid_line_items
    rename_column :bid_line_items, :estimate_id, :bid_id
    add_reference :bids, :project, foreign_key: true
  end
end
