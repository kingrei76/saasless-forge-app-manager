namespace :stripe do
  desc "Phase 0: Create $0/month price, update webhook, store settings for subscription billing"
  task setup_subscription_billing: :environment do
    # Configure Stripe
    key = Setting[:stripe_api_key].presence || ENV["STRIPE_API_KEY"]
    Stripe.api_key = key

    puts "Using Stripe API key: #{key[0..7]}..."
    puts

    # Step 1: Create or find the product
    puts "=== Step 1: Finding or creating product ==="
    product_id = Setting[:stripe_billing_product_id]
    if product_id.present?
      begin
        Stripe::Product.retrieve(product_id)
        puts "Product exists: #{product_id}"
      rescue Stripe::InvalidRequestError
        puts "Stored product #{product_id} not found, creating new one..."
        product_id = nil
      end
    end

    if product_id.blank?
      product = Stripe::Product.create(
        name: "SaaSless Forge - Managed Services",
        description: "Monthly infrastructure and AI usage billing",
        metadata: { purpose: "subscription_billing" }
      )
      product_id = product.id
      Setting[:stripe_billing_product_id] = product_id
      puts "Created product: #{product_id}"
    end

    # Step 2: Create $0/month recurring price
    puts "\n=== Step 2: Creating $0/month recurring price ==="
    existing_price = Setting[:stripe_billing_price_id]
    if existing_price.present?
      begin
        Stripe::Price.retrieve(existing_price)
        puts "Price already exists: #{existing_price}"
      rescue Stripe::InvalidRequestError
        puts "Stored price #{existing_price} not found, creating new one..."
        existing_price = nil
      end
    end

    if existing_price.blank?
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
