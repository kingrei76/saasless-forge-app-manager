class CreateToolCredentials < ActiveRecord::Migration[7.2]
  def change
    create_table :tool_credentials do |t|
      t.references :tool_definition, null: false, foreign_key: true
      t.string :name, null: false
      t.string :credential_type, default: "api_key", null: false
      t.text :encrypted_value
      t.jsonb :config, default: {}
      t.datetime :expires_at
      t.string :status, default: "active", null: false
      t.timestamps
    end

    add_index :tool_credentials, [:tool_definition_id, :name], unique: true, name: "idx_tool_credentials_unique"
    add_index :tool_credentials, :status
  end
end
