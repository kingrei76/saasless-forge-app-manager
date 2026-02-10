class ProjectCompletionService
  attr_reader :project, :final_invoice

  def initialize(project)
    @project = project
  end

  def call
    return { success: false, error: "Project is not in 'adopted' stage" } unless @project.can_complete?

    ActiveRecord::Base.transaction do
      complete_project
      create_final_invoice

      { success: true, project: @project, invoice: @final_invoice }
    end
  rescue StandardError => e
    { success: false, error: e.message }
  end

  private

  def complete_project
    @project.update!(
      stage: "complete",
      status: "completed"
    )
  end

  def create_final_invoice
    deposit_invoice = @project.deposit_invoice
    return unless deposit_invoice

    @final_invoice = Invoice.create!(
      client: @project.client,
      project: @project,
      bid: deposit_invoice.bid,
      parent_invoice: deposit_invoice,
      invoice_type: "bid_based",
      status: "draft",
      payment_type: "final",
      subtotal: deposit_invoice.final_amount,
      total: deposit_invoice.final_amount
    )

    # Add a single line item for the final payment
    @final_invoice.line_items.create!(
      description: "#{@project.title} - Project Development (Final 50% Payment)",
      hours: deposit_invoice.line_items.first&.hours || 0,
      rate: deposit_invoice.bid&.hourly_rate || 0,
      amount: deposit_invoice.final_amount
    )

    # Add actual hours summary if available
    if @project.actual_hours.to_f > 0
      variance = @project.hours_variance_percentage
      variance_text = if variance && variance > 0
                        "(#{variance}% over estimate)"
                      elsif variance && variance < 0
                        "(#{variance.abs}% under estimate)"
                      else
                        "(on target)"
                      end

      @final_invoice.line_items.create!(
        description: "Actual hours logged: #{@project.actual_hours} hours #{variance_text}",
        hours: 0,
        rate: 0,
        amount: 0
      )
    end
  end
end
