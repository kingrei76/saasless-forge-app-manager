class SubscriptionBillingService
  def initialize(client)
    @client = client
  end

  def sync_pending_items!
    configure_stripe!

    period_start, period_end = @client.current_billing_period
    cycle_id = period_start.strftime("%Y-%m")

    results = []

    @client.app_assignments.includes(:app).each do |assignment|
      app = assignment.app

      # Infrastructure costs from CalculatedCost
      infra_result = sync_infrastructure_item(app, period_start, period_end, cycle_id)
      results << infra_result if infra_result

      # AI usage costs from ApiUsageLog
      ai_result = sync_ai_usage_item(app, period_start, period_end, cycle_id)
      results << ai_result if ai_result
    end

    Rails.logger.info("SubscriptionBillingService: Synced #{results.size} pending items for #{@client.name} (#{cycle_id})")
    results
  end

  private

  def sync_infrastructure_item(app, period_start, period_end, cycle_id)
    costs = CalculatedCost.where(
      app: app,
      client: @client,
      billing_period_start: period_start..period_end
    )

    internal_cost = costs.sum(:total_cost)
    return nil if internal_cost.zero?

    markup_pct = MarkupCalculator.for(app: app, client: @client)
    billed_amount = MarkupCalculator.apply(cost: internal_cost, markup_percentage: markup_pct)

    description = "#{app.name} - Infrastructure (#{period_start.strftime('%b %Y')})"

    upsert_pending_item(
      app: app,
      item_type: "infrastructure",
      description: description,
      internal_cost: internal_cost,
      markup_pct: markup_pct,
      billed_amount: billed_amount,
      period_start: period_start,
      period_end: period_end,
      cycle_id: cycle_id
    )
  end

  def sync_ai_usage_item(app, period_start, period_end, cycle_id)
    internal_cost = ApiUsageLog.where(app: app)
      .where(created_at: period_start.beginning_of_day..period_end.end_of_day)
      .sum(:estimated_cost)

    return nil if internal_cost.zero?

    markup_pct = MarkupCalculator.for(app: app, client: @client)
    billed_amount = MarkupCalculator.apply(cost: internal_cost, markup_percentage: markup_pct)

    description = "#{app.name} - AI API Usage (#{period_start.strftime('%b %Y')})"

    upsert_pending_item(
      app: app,
      item_type: "ai_usage",
      description: description,
      internal_cost: internal_cost,
      markup_pct: markup_pct,
      billed_amount: billed_amount,
      period_start: period_start,
      period_end: period_end,
      cycle_id: cycle_id
    )
  end

  def upsert_pending_item(app:, item_type:, description:, internal_cost:, markup_pct:, billed_amount:, period_start:, period_end:, cycle_id:)
    existing = PendingBillingItem.pending.find_by(
      client: @client,
      app: app,
      item_type: item_type,
      billing_cycle_id: cycle_id
    )

    amount_cents = (billed_amount * 100).to_i

    if existing
      # Update existing Stripe InvoiceItem amount
      Stripe::InvoiceItem.update(
        existing.stripe_invoice_item_id,
        amount: amount_cents,
        description: description
      )

      existing.update!(
        internal_cost: internal_cost,
        markup_percentage: markup_pct,
        billed_amount: billed_amount,
        description: description
      )

      Rails.logger.info("SubscriptionBillingService: Updated #{item_type} for #{app.name}: $#{'%.2f' % billed_amount}")
      existing
    else
      # Create new Stripe InvoiceItem (pending — attached to customer, not an invoice)
      stripe_item = Stripe::InvoiceItem.create(
        customer: @client.stripe_customer_id,
        amount: amount_cents,
        currency: "usd",
        description: description,
        metadata: {
          app_hub_client_id: @client.id,
          app_id: app.id,
          item_type: item_type,
          billing_cycle: cycle_id
        }
      )

      pending_item = PendingBillingItem.create!(
        client: @client,
        app: app,
        stripe_invoice_item_id: stripe_item.id,
        item_type: item_type,
        description: description,
        internal_cost: internal_cost,
        markup_percentage: markup_pct,
        billed_amount: billed_amount,
        period_start: period_start,
        period_end: period_end,
        billing_cycle_id: cycle_id
      )

      Rails.logger.info("SubscriptionBillingService: Created #{item_type} for #{app.name}: $#{'%.2f' % billed_amount}")
      pending_item
    end
  end

  def configure_stripe!
    key = Setting[:stripe_api_key].presence || ENV["STRIPE_API_KEY"]
    Stripe.api_key = key if key.present?
  end
end
