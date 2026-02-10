class CreateProjects < ActiveRecord::Migration[7.2]
  def change
    create_table :projects do |t|
      t.references :client, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :status, default: "active"
      t.timestamps
    end
  end
end
