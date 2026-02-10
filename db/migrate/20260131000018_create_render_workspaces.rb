class CreateRenderWorkspaces < ActiveRecord::Migration[7.2]
  def change
    create_table :render_workspaces do |t|
      t.string :render_owner_id, null: false
      t.string :name, null: false
      t.string :email
      t.string :workspace_type  # user, team
      t.string :plan_type       # free, individual, team, organization
      t.integer :user_count
      t.jsonb :raw_data, default: {}

      t.timestamps
    end

    add_index :render_workspaces, :render_owner_id, unique: true
  end
end
