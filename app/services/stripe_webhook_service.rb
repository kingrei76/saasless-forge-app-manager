class StripeWebhookService
  def initialize(event)
    @event = event
    @type = event.type
    @data = event.data.object
  end

  def process!
    configure_stripe!

    case @type
    when "invoice.created"
      handle_invoice_created
    when "invoice.paid"
      handle_invoice_paid
    when "invoice.payment_failed"
      handle_invoice_payment_failed
    when "invoice.overdue"
      handle_invoice_overdue
    when "invoice.finalized"
      handle_invoice_finalized
    when "checkout.session.completed"
      handle_checkout_session_completed
    else
      Rails.logger.info("StripeWebhookService: Unhandled event type #{@type}")
    end

    fire_agent_trigger!
  end

  private

  def handle_invoice_created
    # Only handle subscription-generated invoices (not manually created ones)
    return unless @data.subscription.present?

    # Skip if we already have a local invoice for this Stripe invoice
    return if Invoice.exists?(stripe_invoice_id: @data.id)

    client = Client.find_by(stripe_customer_id: @data.customer)
    return unless client

    # Determine billing period from the Stripe invoice
    period_start = @data.period_start ? Time.at(@data.period_start).to_date : Date.current.beginning_of_month
    period_end = @data.period_end ? Time.at(@data.period_end).to_date : Date.current.end_of_month
    cycle_id = period_start.strftime("%Y-%m")

    pending_items = client.pending_billing_items.pending.for_cycle(cycle_id)

    # Skip if no pending items (the $0 anchor invoice with no usage)
    if pending_items.empty?
      Rails.logger.info("StripeWebhookService: No pending items for #{client.name} cycle #{cycle_id}, skipping invoice creation")
      return
    end

    invoice = Invoice.create!(
      client: client,
      invoice_type: "cost_based",
      payment_type: "infrastructure",
      status: "sent",
      collection_method: @data.collection_method,
      period_start: period_start,
      period_end: period_end,
      stripe_invoice_id: @data.id,
      stripe_status: @data.status,
      stripe_hosted_invoice_url: @data.hosted_invoice_url,
      due_date: @data.due_date ? Time.at(@data.due_date).to_date : nil,
      subtotal: 0,
      total: 0
    )

    # Create line items from pending billing items
    pending_items.each do |pending_item|
      invoice.line_items.create!(
        app_id: pending_item.app_id,
        description: pending_item.description,
        internal_cost: pending_item.internal_cost,
        markup_percentage: pending_item.markup_percentage,
        amount: pending_item.billed_amount
      )

      pending_item.mark_invoiced!(@data.id)
    end

    invoice.recalculate_totals!

    AuditLogger.log(
      user: nil,
      action: "subscription_invoice_created",
      auditable: invoice,
      changes_data: {
        stripe_invoice_id: @data.id,
        client: client.name,
        cycle: cycle_id,
        line_items_count: pending_items.size,
        total: invoice.total.to_f
      }
    )

    Rails.logger.info("StripeWebhookService: Created local Invoice ##{invoice.id} from subscription for #{client.name} (#{cycle_id}), total: $#{'%.2f' % invoice.total}")
  end

  def handle_invoice_paid
    invoice = find_invoice
    return unless invoice

    paid_at = @data.status_transitions&.paid_at
    timestamp = paid_at ? Time.at(paid_at) : Time.current

    invoice.mark_paid_from_stripe!(timestamp)

    AuditLogger.log(
      user: nil,
      action: "stripe_invoice_paid",
      auditable: invoice,
      changes_data: {
        stripe_invoice_id: @data.id,
        amount_paid: @data.amount_paid,
        paid_at: timestamp.iso8601
      }
    )

    Rails.logger.info("StripeWebhookService: Invoice ##{invoice.id} marked as paid via webhook")
  end

  def handle_invoice_payment_failed
    invoice = find_invoice
    return unless invoice

    invoice.mark_failed!

    AuditLogger.log(
      user: nil,
      action: "stripe_payment_failed",
      auditable: invoice,
      changes_data: {
        stripe_invoice_id: @data.id,
        attempt_count: @data.attempt_count
      }
    )

    Rails.logger.warn("StripeWebhookService: Payment failed for Invoice ##{invoice.id}")
  end

  def handle_invoice_overdue
    invoice = find_invoice
    return unless invoice

    invoice.mark_overdue!

    AuditLogger.log(
      user: nil,
      action: "stripe_invoice_overdue",
      auditable: invoice,
      changes_data: { stripe_invoice_id: @data.id }
    )

    Rails.logger.warn("StripeWebhookService: Invoice ##{invoice.id} is overdue")
  end

  def handle_invoice_finalized
    invoice = find_invoice
    return unless invoice

    invoice.update!(
      stripe_status: @data.status,
      stripe_hosted_invoice_url: @data.hosted_invoice_url,
      due_date: @data.due_date ? Time.at(@data.due_date).to_date : nil
    )

    Rails.logger.info("StripeWebhookService: Invoice ##{invoice.id} finalized on Stripe")
  end

  def handle_checkout_session_completed
    return unless @data.mode == "setup"

    client_id = @data.metadata&.app_hub_client_id
    return unless client_id

    client = Client.find_by(id: client_id)
    return unless client

    # Sync the payment method from the setup session
    setup_intent = Stripe::SetupIntent.retrieve(@data.setup_intent)
    payment_method_id = setup_intent.payment_method

    if payment_method_id.present?
      # Set as default on Stripe customer
      Stripe::Customer.update(
        client.stripe_customer_id,
        invoice_settings: { default_payment_method: payment_method_id }
      )

      client.update!(stripe_default_payment_method_id: payment_method_id)

      # Also update the recurring invoice if it exists
      client.recurring_invoice&.update!(stripe_payment_method_id: payment_method_id)

      AuditLogger.log(
        user: nil,
        action: "stripe_payment_method_saved",
        auditable: client,
        changes_data: { payment_method_id: payment_method_id }
      )

      Rails.logger.info("StripeWebhookService: Payment method saved for Client ##{client.id}")
    end
  end

  def fire_agent_trigger!
    event_data = {
      stripe_event_id: @event.id,
      type: @type,
      data: @data.to_h,
      created: @event.created
    }
    AgentTriggerService.fire_event("stripe.#{@type}", event_data)
  rescue => e
    Rails.logger.error("StripeWebhookService: Failed to fire agent trigger: #{e.message}")
  end

  def configure_stripe!
    key = Setting[:stripe_api_key].presence || ENV["STRIPE_API_KEY"]
    Stripe.api_key = key if key.present?
  end

  def find_invoice
    # Look up by stripe_invoice_id
    invoice = Invoice.find_by(stripe_invoice_id: @data.id)

    unless invoice
      # Try metadata fallback
      app_hub_id = @data.metadata&.app_hub_invoice_id
      invoice = Invoice.find_by(id: app_hub_id) if app_hub_id
    end

    unless invoice
      Rails.logger.warn("StripeWebhookService: No local invoice found for Stripe invoice #{@data.id}")
    end

    invoice
  end
end
