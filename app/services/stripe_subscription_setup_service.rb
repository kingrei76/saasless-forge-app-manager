class StripeSubscriptionSetupService
  def initialize(client)
    @client = client
  end

  def create_subscription!
    configure_stripe!
    ensure_stripe_customer!

    price_id = Setting[:stripe_billing_price_id]
    raise "stripe_billing_price_id not configured in Settings" unless price_id.present?

    collection = @client.collection_method || "charge_automatically"

    subscription_params = {
      customer: @client.stripe_customer_id,
      items: [{ price: price_id }],
      collection_method: collection,
      metadata: {
        app_hub_client_id: @client.id,
        purpose: "managed_services_billing"
      }
    }

    if collection == "send_invoice"
      subscription_params[:days_until_due] = @client.recurring_invoice&.days_until_due || 30
    end

    if collection == "charge_automatically" && @client.stripe_default_payment_method_id.present?
      subscription_params[:default_payment_method] = @client.stripe_default_payment_method_id
    end

    # Set billing_cycle_anchor to the 1st of next month for a clean start
    next_month_start = Date.current.next_month.beginning_of_month
    subscription_params[:billing_cycle_anchor] = next_month_start.to_time.to_i

    subscription = Stripe::Subscription.create(subscription_params)

    @client.update!(
      stripe_subscription_id: subscription.id,
      billing_anchor: Time.at(subscription.billing_cycle_anchor).to_date,
      billing_day_of_month: Time.at(subscription.billing_cycle_anchor).day
    )

    AuditLogger.log(
      user: nil,
      action: "stripe_subscription_created",
      auditable: @client,
      changes_data: {
        subscription_id: subscription.id,
        collection_method: collection,
        billing_cycle_anchor: next_month_start.to_s
      }
    )

    Rails.logger.info("StripeSubscriptionSetupService: Created subscription #{subscription.id} for #{@client.name}")
    subscription
  end

  def cancel_subscription!
    configure_stripe!

    return unless @client.stripe_subscription_id.present?

    Stripe::Subscription.cancel(@client.stripe_subscription_id)

    old_id = @client.stripe_subscription_id
    @client.update!(stripe_subscription_id: nil)

    # Void any pending billing items
    @client.pending_billing_items.pending.update_all(status: "void")

    AuditLogger.log(
      user: nil,
      action: "stripe_subscription_cancelled",
      auditable: @client,
      changes_data: { subscription_id: old_id }
    )

    Rails.logger.info("StripeSubscriptionSetupService: Cancelled subscription #{old_id} for #{@client.name}")
  end

  private

  def configure_stripe!
    key = Setting[:stripe_api_key].presence || ENV["STRIPE_API_KEY"]
    Stripe.api_key = key if key.present?
  end

  def ensure_stripe_customer!
    return if @client.stripe_customer_id.present?

    customer = Stripe::Customer.create(
      email: @client.email,
      name: @client.name,
      metadata: { app_hub_client_id: @client.id }
    )

    @client.update!(stripe_customer_id: customer.id)
  end
end
