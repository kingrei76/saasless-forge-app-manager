# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#

user = User.find_or_create_by!(email: "ammonlewis@gmail.com") do |user|
  user.name = "Ammon Lewis"
  user.password = SecureRandom.hex(16)
end
user.update!(admin: true, role: :admin) unless user.admin?

# Authorized emails for Google OAuth login
AllowedEmail.find_or_create_by!(email: "ammonlewis@gmail.com")
puts "Authorized emails seeded."

# Default settings
Setting.find_or_create_by!(key: "default_markup_percentage") do |s|
  s.value = "30.0"
end

Setting.find_or_create_by!(key: "default_hourly_rate") do |s|
  s.value = "150.0"
end

# Seed Render pricing data
puts "Seeding Render pricing data..."
RenderPricingScraper.new.seed_default_prices
puts "Render pricing data seeded."

# Clients
puts "Seeding clients..."
clients = {
  "Thayne Lewis" => { email: "Thayne@Ajetservices.com", company: "AJET Services", markup: "30.0", app: "AJet-Admin-App" },
  "Internal Apps" => { email: "ammonlewis@gmail.com", company: "SaaSless Forge", markup: nil, app: "saasless-forge-app-manager" },
  "Chris Eberth" => { email: "", company: "Green leaf Landscaping", markup: "30.0", app: "greenleaf-bidding-tool" }
}

# Service Providers
puts "Seeding service providers..."
ServiceProvider.find_or_create_by!(slug: "grok") do |sp|
  sp.name = "xAI / Grok"
  sp.category = "llm"
  sp.base_url = "https://api.x.ai/v1"
  sp.proxy_enabled = true
  sp.sync_enabled = false
  sp.sync_adapter = "UsageSyncAdapters::Grok"
  sp.pricing_rules = {
    "type" => "per_token",
    "models" => {
      "grok-3"        => { "input" => 3.00, "output" => 15.00 },
      "grok-2-latest" => { "input" => 2.00, "output" => 10.00 },
      "grok-beta"     => { "input" => 5.00, "output" => 15.00 }
    }
  }
end
puts "Service providers seeded."

clients.each do |name, data|
  client = Client.find_or_create_by!(name: name) do |c|
    c.email = data[:email]
    c.company = data[:company]
    c.markup_percentage = data[:markup]
    c.collection_method = "send_invoice"
  end

  if data[:app].present?
    app = App.find_by(name: data[:app])
    if app
      AppAssignment.find_or_create_by!(app: app, client: client)
      puts "  #{name} -> #{app.name}"
    else
      puts "  #{name} -> app '#{data[:app]}' not found (will be linked after app sync)"
    end
  end
end
puts "Clients seeded."
