class AddProjectScopeToBids < ActiveRecord::Migration[7.2]
  def change
    add_column :bids, :project_scope, :string, default: "small_feature"
  end
end
