class CreateAgents < ActiveRecord::Migration[7.2]
  def change
    create_table :agents do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.text :system_prompt
      t.string :category, default: "custom", null: false
      t.string :status, default: "draft", null: false
      t.string :mode, default: "test", null: false
      t.integer :version, default: 1, null: false
      t.integer :max_iterations, default: 25
      t.decimal :temperature, precision: 3, scale: 2, default: 0.7
      t.string :model_name
      t.references :service_provider, foreign_key: true
      t.jsonb :config, default: {}
      t.jsonb :memory_config, default: {}
      t.jsonb :metadata, default: {}
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :agents, :slug, unique: true
    add_index :agents, :status
    add_index :agents, :category
    add_index :agents, :mode
  end
end
