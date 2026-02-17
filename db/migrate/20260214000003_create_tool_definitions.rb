class CreateToolDefinitions < ActiveRecord::Migration[7.2]
  def change
    create_table :tool_definitions do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.string :handler_class
      t.string :category, default: "other", null: false
      t.jsonb :input_schema, default: {}
      t.jsonb :output_schema, default: {}
      t.integer :version, default: 1, null: false
      t.string :risk_level, default: "low", null: false
      t.string :status, default: "active", null: false
      t.jsonb :config, default: {}
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :tool_definitions, :slug, unique: true
    add_index :tool_definitions, :category
    add_index :tool_definitions, :status
    add_index :tool_definitions, :risk_level
  end
end
