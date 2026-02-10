class InvoiceBuilder
  def initialize(client:, period_start:, period_end:)
    @client = client
    @period_start = period_start
    @period_end = period_end
  end

  def build
    invoice = Invoice.new(
      client: @client,
      period_start: @period_start,
      period_end: @period_end,
      status: "draft",
      invoice_type: "cost_based"
    )

    @client.apps.included.each do |app|
      cost = app.total_cost(period_start: @period_start, period_end: @period_end)
      next if cost.zero?

      markup = MarkupCalculator.for(app: app, client: @client)

      invoice.line_items.build(
        app: app,
        description: "#{app.name} — #{@period_start.strftime('%b %Y')}",
        internal_cost: cost,
        markup_percentage: markup,
        amount: MarkupCalculator.apply(cost: cost, markup_percentage: markup)
      )
    end

    invoice.subtotal = invoice.line_items.sum(&:internal_cost)
    invoice.total = invoice.line_items.sum(&:amount)
    invoice
  end
end
