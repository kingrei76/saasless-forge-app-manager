class CreateCostEntries < ActiveRecord::Migration[7.2]
  def change
    create_table :cost_entries do |t|
      t.references :app, null: false, foreign_key: true
      t.string :service_name, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :currency, default: "USD"
      t.date :period_start
      t.date :period_end
      t.text :notes

      t.timestamps
    end
  end
end
