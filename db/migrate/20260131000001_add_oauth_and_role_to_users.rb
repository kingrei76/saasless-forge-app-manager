class AddOauthAndRoleToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :provider, :string
    add_column :users, :uid, :string
    add_column :users, :avatar_url, :string
    add_column :users, :role, :integer, default: 0

    add_index :users, [:provider, :uid], unique: true
  end
end
