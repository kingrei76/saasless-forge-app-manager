class CreateClients < ActiveRecord::Migration[7.2]
  def change
    create_table :clients do |t|
      t.string :name, null: false
      t.string :email
      t.string :company
      t.string :stripe_customer_id
      t.decimal :markup_percentage, precision: 5, scale: 2

      t.timestamps
    end
  end
end
