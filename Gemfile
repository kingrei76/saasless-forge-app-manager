source "https://rubygems.org"

ruby "3.3.4"

gem "rails", "~> 7.2"

# Database
gem "pg", "~> 1.5"

# Web server
gem "puma", ">= 5.0"

# Asset pipeline
gem "sprockets-rails"
gem "importmap-rails"

# Hotwire
gem "turbo-rails"
gem "stimulus-rails"

# Background jobs
gem "solid_queue"

# Authentication & Authorization
gem "devise"
gem "pundit"

# Payments
gem "stripe"

# Active Storage
gem "image_processing", "~> 1.2"

# ActionText
gem "actiontext"

# Redis (ActionCable in production)
gem "redis", ">= 4.0.1"

# JSON APIs
gem "jbuilder"

# Boot performance
gem "bootsnap", require: false

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "rspec-rails"
  gem "factory_bot_rails"
end

group :development do
  gem "web-console"
end
