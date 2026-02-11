class MonthlyInfrastructureBillingService
  attr_reader :client, :billing_period_start, :billing_period_end, :invoice

  def initialize(client, billing_period_start: nil, billing_period_end: nil)
    @client = client
    @billing_period_start = billing_period_start || Date.current.beginning_of_month
    @billing_period_end = billing_period_end || Date.current.end_of_month
  end

  def call
    return { success: false, error: "No apps assigned to client" } unless client_has_apps?
    return { success: false, error: "Invoice already exists for this period" } if invoice_exists_for_period?

    ActiveRecord::Base.transaction do
      create_infrastructure_invoice
      add_app_cost_line_items
      add_api_usage_line_items

      if @invoice.line_items.any? && @invoice.total > 0
        { success: true, invoice: @invoice }
      else
        @invoice.destroy
        { success: false, error: "No billable costs for this period" }
      end
    end
  rescue StandardError => e
    { success: false, error: e.message }
  end

  def self.generate_for_all_clients(billing_period_start: nil, billing_period_end: nil)
    results = []

    Client.includes(:app_assignments, apps: :render_services).find_each do |client|
      next unless client.app_assignments.any?

      service = new(client, billing_period_start: billing_period_start, billing_period_end: billing_period_end)
      result = service.call

      results << {
        client: client,
        success: result[:success],
        invoice: result[:invoice],
        error: result[:error]
      }
    end

    results
  end

  private

  def client_has_apps?
    @client.app_assignments.any?
  end

  def invoice_exists_for_period?
    @client.invoices
           .infrastructure
           .where(period_start: @billing_period_start, period_end: @billing_period_end)
           .where.not(status: "void")
           .exists?
  end

  def create_infrastructure_invoice
    @invoice = Invoice.create!(
      client: @client,
      invoice_type: "cost_based",
      status: "draft",
      payment_type: "infrastructure",
      period_start: @billing_period_start,
      period_end: @billing_period_end,
      subtotal: 0,
      total: 0
    )
  end

  def add_app_cost_line_items
    subtotal = 0
    internal_cost_total = 0

    @client.app_assignments.includes(app: :render_services).each do |assignment|
      app = assignment.app
      next unless app.included?

      # Get calculated costs for this billing period
      calculated_costs = CalculatedCost.where(
        app: app,
        client: @client,
        billing_period_start: @billing_period_start,
        billing_period_end: @billing_period_end
      )

      if calculated_costs.any?
        # Use pre-calculated costs
        calculated_costs.each do |calc_cost|
          markup_percentage = assignment.markup_percentage || @client.markup_percentage || default_markup
          marked_up_cost = apply_markup(calc_cost.total_cost, markup_percentage)

          @invoice.line_items.create!(
            app: app,
            description: "#{app.name} - #{calc_cost.service_type} (#{calc_cost.plan_name})",
            internal_cost: calc_cost.total_cost,
            markup_percentage: markup_percentage,
            amount: marked_up_cost
          )

          subtotal += marked_up_cost
          internal_cost_total += calc_cost.total_cost
        end
      else
        # Fall back to estimating from RenderServices
        app.render_services.each do |render_service|
          next if render_service.suspended?

          base_cost = estimate_service_cost(render_service)
          next if base_cost.zero?

          markup_percentage = assignment.markup_percentage || @client.markup_percentage || default_markup
          marked_up_cost = apply_markup(base_cost, markup_percentage)

          @invoice.line_items.create!(
            app: app,
            description: "#{app.name} - #{render_service.service_type} (#{render_service.plan})",
            internal_cost: base_cost,
            markup_percentage: markup_percentage,
            amount: marked_up_cost
          )

          subtotal += marked_up_cost
          internal_cost_total += base_cost
        end
      end
    end

    @invoice.update!(subtotal: internal_cost_total, total: subtotal)
  end

  def add_api_usage_line_items
    @client.app_assignments.includes(:app).each do |assignment|
      app = assignment.app
      next unless app.included?

      usage_cost = ApiUsageLog.where(app_id: app.id)
                              .where(created_at: @billing_period_start.beginning_of_day..@billing_period_end.end_of_day)
                              .sum(:estimated_cost)

      next if usage_cost.nil? || usage_cost.zero?

      markup_percentage = assignment.markup_percentage || @client.markup_percentage || default_markup
      marked_up_cost = apply_markup(usage_cost, markup_percentage)

      @invoice.line_items.create!(
        app: app,
        description: "#{app.name} - AI API Usage",
        internal_cost: usage_cost,
        markup_percentage: markup_percentage,
        amount: marked_up_cost
      )

      # Update totals
      @invoice.subtotal = (@invoice.subtotal || 0) + usage_cost
      @invoice.total = (@invoice.total || 0) + marked_up_cost
      @invoice.save!
    end
  end

  def estimate_service_cost(render_service)
    render_service.monthly_price
  end

  def apply_markup(cost, markup_percentage)
    MarkupCalculator.apply(cost: cost, markup_percentage: markup_percentage)
  end

  def default_markup
    Setting[:default_markup_percentage]&.to_f || 30.0
  end
end
