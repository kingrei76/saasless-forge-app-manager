class RecurringBillingService
  def self.process_all_due
    results = []

    RecurringInvoice.due_today.includes(:client).find_each do |recurring|
      result = new(recurring).process!
      results << result
    end

    results
  end

  def self.generate_drafts_for_due
    results = []

    RecurringInvoice.due_today.includes(:client).find_each do |recurring|
      result = new(recurring).generate_draft!
      results << result
    end

    results
  end

  def initialize(recurring_invoice)
    @recurring = recurring_invoice
    @client = recurring_invoice.client
  end

  def process!
    period_start, period_end = @recurring.billing_period_for_next_run

    # Generate the infrastructure invoice using existing service
    billing_service = MonthlyInfrastructureBillingService.new(
      @client,
      billing_period_start: period_start,
      billing_period_end: period_end
    )

    result = billing_service.call

    unless result[:success]
      return { client: @client, success: false, error: result[:error] }
    end

    invoice = result[:invoice]

    # Link to recurring invoice
    invoice.update!(recurring_invoice: @recurring)

    # Add API usage line items for the period
    add_api_usage_line_items(invoice, period_start, period_end)

    # Recalculate totals after adding API usage
    invoice.recalculate_totals! if invoice.line_items.count > 0

    # Send to Stripe
    if invoice.total > 0
      stripe_service = StripeInvoiceService.new(invoice)
      stripe_service.create_and_send!
    end

    # Advance billing date
    @recurring.update!(last_billed_date: Date.current)
    @recurring.compute_next_billing_date!

    AuditLogger.log(
      user: nil,
      action: "recurring_invoice_generated",
      auditable: invoice,
      changes_data: {
        client: @client.name,
        period: "#{period_start} to #{period_end}",
        total: invoice.total.to_f
      }
    )

    { client: @client, success: true, invoice: invoice }
  rescue StandardError => e
    Rails.logger.error("RecurringBillingService error for client #{@client.id}: #{e.message}")
    { client: @client, success: false, error: e.message }
  end

  def generate_draft!
    period_start, period_end = @recurring.billing_period_for_next_run

    billing_service = MonthlyInfrastructureBillingService.new(
      @client,
      billing_period_start: period_start,
      billing_period_end: period_end
    )

    result = billing_service.call

    unless result[:success]
      return { client: @client, success: false, error: result[:error] }
    end

    invoice = result[:invoice]
    invoice.update!(recurring_invoice: @recurring)

    add_api_usage_line_items(invoice, period_start, period_end)
    invoice.recalculate_totals! if invoice.line_items.count > 0

    # Advance billing date (but do NOT send to Stripe — leave as draft for review)
    @recurring.update!(last_billed_date: Date.current)
    @recurring.compute_next_billing_date!

    AuditLogger.log(
      user: nil,
      action: "recurring_draft_generated",
      auditable: invoice,
      changes_data: {
        client: @client.name,
        period: "#{period_start} to #{period_end}",
        total: invoice.total.to_f
      }
    )

    { client: @client, success: true, invoice: invoice }
  rescue StandardError => e
    Rails.logger.error("RecurringBillingService draft error for client #{@client.id}: #{e.message}")
    { client: @client, success: false, error: e.message }
  end

  private

  def add_api_usage_line_items(invoice, period_start, period_end)
    # Group API usage by app for the billing period
    @client.apps.each do |app|
      usage_cost = ApiUsageLog.where(app_id: app.id)
                              .where(created_at: period_start.beginning_of_day..period_end.end_of_day)
                              .sum(:estimated_cost)

      next if usage_cost.nil? || usage_cost.zero?

      assignment = @client.app_assignments.find_by(app: app)
      markup_percentage = assignment&.markup_percentage || @client.markup_percentage || default_markup
      marked_up_cost = MarkupCalculator.apply(cost: usage_cost, markup_percentage: markup_percentage)

      invoice.line_items.create!(
        app: app,
        description: "#{app.name} - AI API Usage",
        internal_cost: usage_cost,
        markup_percentage: markup_percentage,
        amount: marked_up_cost
      )
    end
  end

  def default_markup
    Setting[:default_markup_percentage]&.to_f || 30.0
  end
end
