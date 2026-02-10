class EnhanceProjectsForWorkflow < ActiveRecord::Migration[7.2]
  def change
    add_reference :projects, :assignee, foreign_key: { to_table: :users }
    add_column :projects, :stage, :string, default: "in_development"
    add_column :projects, :development_due_date, :date
    add_column :projects, :go_live_date, :date
    add_column :projects, :adoption_due_date, :date
    add_column :projects, :estimated_hours, :decimal, precision: 8, scale: 2
    add_column :projects, :actual_hours, :decimal, precision: 8, scale: 2, default: 0
    add_column :projects, :source_bid_id, :bigint

    add_index :projects, :stage
    add_index :projects, :source_bid_id
  end
end
