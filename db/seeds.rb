# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#

user = User.find_or_create_by!(email: 'admin@example.com') do |user|
  user.password = '123456'
  user.password_confirmation = '123456'
end
user.update!(admin: true, role: :admin) unless user.admin?

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
