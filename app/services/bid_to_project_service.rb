class BidToProjectService
  attr_reader :bid, :assignee, :project, :invoice

  def initialize(bid, assignee: nil)
    @bid = bid
    @assignee = assignee
  end

  def call
    ActiveRecord::Base.transaction do
      create_project
      copy_apps_from_bid
      create_deposit_invoice
      update_bid_status

      { success: true, project: @project, invoice: @invoice }
    end
  rescue StandardError => e
    { success: false, error: e.message }
  end

  private

  def create_project
    @project = Project.create!(
      client: @bid.client,
      title: @bid.title,
      description: @bid.requirements_summary.presence || @bid.project_description,
      status: "active",
      stage: "in_development",
      assignee: @assignee,
      source_bid: @bid,
      estimated_hours: @bid.estimated_hours_total
    )

    # Link the project back to the bid
    @bid.update!(project: @project)
  end

  def copy_apps_from_bid
    @bid.bid_apps.each_with_index do |bid_app, index|
      @project.project_apps.create!(
        app: bid_app.app,
        new_app_name: bid_app.new_app_name,
        primary: index == 0  # First app is primary
      )
    end
  end

  def create_deposit_invoice
    development_total = @bid.development_subtotal
    deposit_amount = (development_total * 0.50).round(2)
    final_amount = development_total - deposit_amount

    @invoice = Invoice.create!(
      client: @bid.client,
      project: @project,
      bid: @bid,
      invoice_type: "bid_based",
      status: "draft",
      payment_type: "deposit",
      deposit_percentage: 50.0,
      deposit_amount: deposit_amount,
      final_amount: final_amount,
      subtotal: deposit_amount,
      total: deposit_amount
    )

    # Add a single line item for the deposit
    @invoice.line_items.create!(
      description: "#{@project.title} - Project Development (50% Deposit)",
      hours: @bid.development_hours_total,
      rate: @bid.hourly_rate,
      amount: deposit_amount
    )

    # Add informational note about system costs (billed separately)
    if @bid.system_cost_line_items.any?
      monthly_total = @bid.system_cost_line_items.sum(&:display_price)
      @invoice.line_items.create!(
        description: "Note: Monthly infrastructure costs (~#{number_to_currency(monthly_total)}/mo) will be billed separately",
        hours: 0,
        rate: 0,
        amount: 0
      )
    end
  end

  def update_bid_status
    @bid.update!(status: "accepted")
  end

  def number_to_currency(amount)
    "$#{'%.2f' % amount}"
  end
end
