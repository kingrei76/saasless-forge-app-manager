class StripeInvoiceService
  def initialize(invoice)
    @invoice = invoice
    @client = invoice.client
  end

  MINIMUM_SEND_AMOUNT = 0.50 # Stripe minimum for USD invoices

  def create_and_send!
    if @invoice.total < MINIMUM_SEND_AMOUNT
      raise "Invoice total (#{@invoice.total}) is below Stripe's minimum of $#{'%.2f' % MINIMUM_SEND_AMOUNT}. Costs will accumulate until the next billing period."
    end

    ensure_stripe_customer!

    collection = determine_collection_method
    invoice_params = {
      customer: @client.stripe_customer_id,
      collection_method: collection,
      metadata: {
        app_hub_invoice_id: @invoice.id,
        period_start: @invoice.period_start,
        period_end: @invoice.period_end
      }
    }

    if collection == "send_invoice"
      invoice_params[:days_until_due] = determine_days_until_due
    end

    if collection == "charge_automatically" && @client.stripe_default_payment_method_id.present?
      invoice_params[:default_payment_method] = @client.stripe_default_payment_method_id
    end

    stripe_invoice = Stripe::Invoice.create(invoice_params)

    if @invoice.deposit?
      # For 50% deposit invoices, send a single line item with the deposit total
      Stripe::InvoiceItem.create(
        customer: @client.stripe_customer_id,
        invoice: stripe_invoice.id,
        amount: (@invoice.total * 100).to_i, # cents
        currency: "usd",
        description: "#{@invoice.line_items.first&.description || 'Project Deposit'} — 50% Deposit"
      )
    else
      @invoice.line_items.each do |li|
        Stripe::InvoiceItem.create(
          customer: @client.stripe_customer_id,
          invoice: stripe_invoice.id,
          amount: (li.amount * 100).to_i, # cents
          currency: "usd",
          description: li.description
        )
      end
    end

    Stripe::Invoice.finalize_invoice(stripe_invoice.id)

    # Refresh to get hosted_invoice_url and other fields
    stripe_invoice = Stripe::Invoice.retrieve(stripe_invoice.id)

    if collection == "send_invoice"
      Stripe::Invoice.send_invoice(stripe_invoice.id)
    end

    @invoice.update!(
      stripe_invoice_id: stripe_invoice.id,
      status: "sent",
      stripe_hosted_invoice_url: stripe_invoice.hosted_invoice_url,
      stripe_status: stripe_invoice.status,
      collection_method: collection,
      due_date: stripe_invoice.due_date ? Time.at(stripe_invoice.due_date).to_date : nil
    )

    stripe_invoice
  rescue Stripe::StripeError => e
    Rails.logger.error("Stripe invoice creation failed: #{e.message}")
    raise
  end

  def mark_paid!
    @invoice.update!(status: "paid")
  end

  private

  def determine_collection_method
    # Priority: invoice → recurring_invoice → client → default
    @invoice.collection_method ||
      @invoice.recurring_invoice&.collection_method ||
      @client.collection_method ||
      "send_invoice"
  end

  def determine_days_until_due
    @invoice.recurring_invoice&.days_until_due || 30
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
