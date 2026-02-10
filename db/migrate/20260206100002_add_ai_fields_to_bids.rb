class AddAiFieldsToBids < ActiveRecord::Migration[7.2]
  def change
    add_column :bids, :ai_generated, :boolean, default: false
    add_column :bids, :requirements_summary, :text
    add_column :bids, :wizard_state, :jsonb, default: {}
    add_column :bids, :estimated_hours_total, :decimal, precision: 8, scale: 2
    add_column :bids, :monthly_costs_total, :decimal, precision: 10, scale: 2, default: 0
  end
end
