class CreateEstimateLineItems < ActiveRecord::Migration[7.2]
  def change
    create_table :estimate_line_items do |t|
      t.references :estimate, null: false, foreign_key: true
      t.string :description
      t.decimal :hours, precision: 8, scale: 2
      t.decimal :rate, precision: 10, scale: 2
      t.decimal :subtotal, precision: 10, scale: 2
      t.integer :position

      t.timestamps
    end
  end
end
