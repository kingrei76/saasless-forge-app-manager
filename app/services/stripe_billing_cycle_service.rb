class StripeBillingCycleService
  def initialize
    @stripe_api_key = Setting[:stripe_secret_key]
  end

  def sync_all_clients
    return { error: "Stripe API key not configured" } if @stripe_api_key.blank?

    Stripe.api_key = @stripe_api_key

    results = { synced: 0, skipped: 0, errors: [] }

    Client.where.not(stripe_customer_id: nil).find_each do |client|
      sync_client(client, results)
    end

    results
  end

  def sync_client(client, results = { synced: 0, skipped: 0, errors: [] })
    return results if client.stripe_customer_id.blank?

    begin
      Stripe.api_key = @stripe_api_key if @stripe_api_key.present?

      subscriptions = Stripe::Subscription.list(
        customer: client.stripe_customer_id,
        status: "active",
        limit: 1
      )

      subscription = subscriptions.data.first

      if subscription
        billing_anchor = Time.at(subscription.billing_cycle_anchor).to_date
        billing_day = billing_anchor.day

        client.update!(
          stripe_subscription_id: subscription.id,
          billing_anchor: billing_anchor,
          billing_day_of_month: billing_day,
          billing_cycle_last_synced_at: Time.current
        )

        results[:synced] += 1
      else
        results[:skipped] += 1
      end
    rescue Stripe::StripeError => e
      results[:errors] << { client_id: client.id, error: e.message }
    rescue => e
      results[:errors] << { client_id: client.id, error: e.message }
    end

    results
  end

  def get_billing_period(client)
    client.current_billing_period
  end

  def sync_client_by_subscription_id(subscription_id)
    client = Client.find_by(stripe_subscription_id: subscription_id)
    return { error: "Client not found" } unless client

    sync_client(client)
  end
end
