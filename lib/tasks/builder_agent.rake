namespace :agents do
  desc "Seed the Agent Builder agent with all 16 built-in tools"
  task seed_builder: :environment do
    load Rails.root.join("db/seeds/builder_agent.rb")
    seed_builder_agent!
  end
end
