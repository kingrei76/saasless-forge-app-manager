class StripePaymentMethodService
  def initialize(client)
    @client = client
  end

  def create_setup_session(success_url:, cancel_url:)
    configure_stripe!
    ensure_stripe_customer!

    Stripe::Checkout::Session.create(
      customer: @client.stripe_customer_id,
      mode: "setup",
      payment_method_types: ["card"],
      success_url: success_url,
      cancel_url: cancel_url,
      metadata: {
        app_hub_client_id: @client.id
      }
    )
  end

  def sync_default_payment_method!
    configure_stripe!
    return unless @client.stripe_customer_id.present?

    customer = Stripe::Customer.retrieve(@client.stripe_customer_id)
    payment_method_id = customer.invoice_settings&.default_payment_method

    # If no default set on invoice_settings, try the first available payment method
    if payment_method_id.blank?
      payment_methods = Stripe::PaymentMethod.list(
        customer: @client.stripe_customer_id,
        type: "card"
      )
      payment_method_id = payment_methods.data.first&.id
    end

    if payment_method_id.present?
      # Set as default on Stripe customer for invoices
      Stripe::Customer.update(
        @client.stripe_customer_id,
        invoice_settings: { default_payment_method: payment_method_id }
      )

      @client.update!(stripe_default_payment_method_id: payment_method_id)
    end

    payment_method_id
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
