class CreateEstimates < ActiveRecord::Migration[7.2]
  def change
    create_table :estimates do |t|
      t.references :client, foreign_key: true
      t.string :title, null: false
      t.string :status, default: "draft"
      t.decimal :hourly_rate, precision: 10, scale: 2
      t.decimal :total, precision: 10, scale: 2, default: 0
      t.text :notes

      t.timestamps
    end
  end
end
