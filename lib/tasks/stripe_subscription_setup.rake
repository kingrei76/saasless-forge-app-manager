namespace :stripe do
  desc "Phase 0: Create $0/month price, update webhook, store settings for subscription billing"
  task setup_subscription_billing: :environment do
    product_id = "prod_TzX9D9AfE5GuSW"

    # Configure Stripe
    key = Setting[:stripe_api_key].presence || ENV["STRIPE_API_KEY"]
    Stripe.api_key = key

    puts "Using Stripe API key: #{key[0..7]}..."
    puts

    # Step 1: Create $0/month recurring price
    puts "=== Step 1: Creating $0/month recurring price ==="
    existing_price = Setting[:stripe_billing_price_id]
    if existing_price.present?
      puts "Price already exists: #{existing_price}"
    else
      price = Stripe::Price.create(
        product: product_id,
        unit_amount: 0,
        currency: "usd",
        recurring: { interval: "month" },
        metadata: { purpose: "subscription_billing_anchor" }
      )
      Setting[:stripe_billing_price_id] = price.id
      puts "Created price: #{price.id}"
    end

    # Step 2: Store product ID
    puts "\n=== Step 2: Storing product ID ==="
    Setting[:stripe_billing_product_id] = product_id
    puts "Stored stripe_billing_product_id = #{product_id}"

    # Step 3: Add invoice.created to webhook endpoint
    puts "\n=== Step 3: Updating webhook endpoint ==="
    webhook_endpoint_id = "we_1SzU5M0w9yk7gbwk9HaPZdFK"
    begin
      endpoint = Stripe::WebhookEndpoint.retrieve(webhook_endpoint_id)
      current_events = endpoint.enabled_events

      if current_events.include?("invoice.created")
        puts "invoice.created already registered"
      else
        new_events = current_events + ["invoice.created"]
        Stripe::WebhookEndpoint.update(webhook_endpoint_id, enabled_events: new_events)
        puts "Added invoice.created to webhook endpoint"
      end
      puts "Enabled events: #{new_events || current_events}"
    rescue Stripe::StripeError => e
      puts "WARNING: Could not update webhook: #{e.message}"
      puts "You may need to add invoice.created manually in the Stripe Dashboard"
    end

    puts "\n=== Setup Complete ==="
    puts "stripe_billing_product_id: #{Setting[:stripe_billing_product_id]}"
    puts "stripe_billing_price_id:   #{Setting[:stripe_billing_price_id]}"
    puts
    puts "Next: Enable Customer Portal in Stripe Dashboard > Settings > Billing > Customer portal"
  end
end
