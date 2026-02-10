class BidToInvoiceService
  # NOTE: This service is now primarily used for creating full invoices from bids.
  # For the new 50/50 split payment workflow, use BidToProjectService instead.
  # This service remains for backwards compatibility and manual invoice creation.

  def initialize(bid, payment_type: "full")
    @bid = bid
    @payment_type = payment_type
  end

  def call
    # Create a project from the bid if one doesn't exist
    project = @bid.project || create_project_from_bid

    invoice = Invoice.new(
      client: @bid.client,
      project: project,
      bid: @bid,
      invoice_type: "bid_based",
      status: "draft",
      payment_type: @payment_type
    )

    # Add development line items
    @bid.development_line_items.each do |bid_item|
      invoice.line_items.build(
        description: bid_item.description,
        hours: bid_item.hours,
        rate: bid_item.rate,
        amount: bid_item.subtotal
      )
    end

    # Add system cost line items (using display_price, not unit_cost)
    @bid.system_cost_line_items.each do |bid_item|
      description = bid_item.description
      description += " (Monthly)" if bid_item.recurring?

      invoice.line_items.build(
        description: description,
        internal_cost: bid_item.unit_cost,
        amount: bid_item.display_price
      )
    end

    invoice.subtotal = invoice.line_items.sum(&:amount)
    invoice.total = invoice.subtotal
    invoice.save!
    invoice
  end

  private

  def create_project_from_bid
    project = Project.create!(
      client: @bid.client,
      title: @bid.title,
      description: @bid.requirements_summary.presence || @bid.project_description,
      status: "active",
      stage: "in_development",
      source_bid: @bid,
      estimated_hours: @bid.estimated_hours_total
    )

    # Link the project back to the bid
    @bid.update!(project: project)

    project
  end
end
