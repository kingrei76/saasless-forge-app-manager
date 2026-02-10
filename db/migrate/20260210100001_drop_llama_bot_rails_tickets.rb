class DropLlamaBotRailsTickets < ActiveRecord::Migration[7.2]
  def up
    drop_table :llama_bot_rails_tickets, if_exists: true
  end

  def down
    create_table :llama_bot_rails_tickets do |t|
      t.string :status
      t.text :description
      t.text :research_notes
      t.timestamps
    end
  end
end
