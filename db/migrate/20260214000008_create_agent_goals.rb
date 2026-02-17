class CreateAgentGoals < ActiveRecord::Migration[7.2]
  def change
    create_table :agent_goals do |t|
      t.references :agent, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.text :success_criteria
      t.integer :priority, default: 0
      t.string :status, default: "active", null: false
      t.timestamps
    end

    add_index :agent_goals, [:agent_id, :status]
  end
end
