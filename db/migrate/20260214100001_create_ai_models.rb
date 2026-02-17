class CreateAiModels < ActiveRecord::Migration[7.2]
  def change
    create_table :ai_models do |t|
      t.references :service_provider, null: false, foreign_key: true
      t.string :name, null: false
      t.string :model_id, null: false
      t.string :category, default: "chat", null: false
      t.integer :context_window
      t.integer :max_output_tokens
      t.decimal :input_price_per_million, precision: 10, scale: 4
      t.decimal :output_price_per_million, precision: 10, scale: 4
      t.jsonb :capabilities, default: {}
      t.string :status, default: "active", null: false
      t.integer :sort_order, default: 0
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :ai_models, [:service_provider_id, :model_id], unique: true
    add_index :ai_models, :model_id
    add_index :ai_models, :status
    add_index :ai_models, :category
  end
end
