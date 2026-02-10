class CreateBidApps < ActiveRecord::Migration[7.2]
  def change
    create_table :bid_apps do |t|
      t.references :bid, null: false, foreign_key: true
      t.references :app, foreign_key: true
      t.string :new_app_name
      t.timestamps
    end

    add_reference :bid_line_items, :bid_app, foreign_key: true
  end
end
