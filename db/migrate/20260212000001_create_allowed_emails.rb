class CreateAllowedEmails < ActiveRecord::Migration[7.2]
  def change
    create_table :allowed_emails do |t|
      t.string :email, null: false
      t.timestamps
    end

    add_index :allowed_emails, :email, unique: true
  end
end
