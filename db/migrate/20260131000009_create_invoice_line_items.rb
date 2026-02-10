class CreateInvoiceLineItems < ActiveRecord::Migration[7.2]
  def change
    create_table :invoice_line_items do |t|
      t.references :invoice, null: false, foreign_key: true
      t.references :app, foreign_key: true
      t.string :description
      t.decimal :internal_cost, precision: 10, scale: 2
      t.decimal :markup_percentage, precision: 5, scale: 2
      t.decimal :amount, precision: 10, scale: 2

      t.timestamps
    end
  end
end
