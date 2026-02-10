class Admin::InvoicesController < Admin::BaseController
  before_action :require_admin!
  before_action :set_invoice, only: [:show, :edit, :update, :destroy, :send_to_stripe, :mark_paid, :archive, :preview_send, :void_stripe, :duplicate_as_draft, :sync_stripe]

  def index
    @invoices = Invoice.includes(:client).order(created_at: :desc)
    if params[:status].present?
      @invoices = @invoices.by_status(params[:status])
    else
      @invoices = @invoices.visible
    end
  end

  def show
    @line_items = @invoice.line_items.includes(:app)
  end

  def new
    @clients = Client.order(:name)

    if params[:client_id].present? && params[:period_start].present? && params[:period_end].present?
      client = Client.find(params[:client_id])
      builder = InvoiceBuilder.new(
        client: client,
        period_start: Date.parse(params[:period_start]),
        period_end: Date.parse(params[:period_end])
      )
      @invoice = builder.build
    else
      @invoice = Invoice.new(invoice_type: "cost_based")
    end
  end

  def create
    @invoice = Invoice.new(invoice_params)
    @invoice.status = "draft"
    @invoice.invoice_type = "cost_based" if @invoice.invoice_type.blank?

    if @invoice.save
      redirect_to admin_invoice_path(@invoice), notice: "Invoice created."
    else
      @clients = Client.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @clients = Client.order(:name)
  end

  def update
    if @invoice.update(invoice_params)
      redirect_to admin_invoice_path(@invoice), notice: "Invoice updated."
    else
      @clients = Client.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    unless @invoice.status.in?(%w[draft archived])
      redirect_to admin_invoice_path(@invoice), alert: "Only draft or archived invoices can be deleted."
      return
    end

    @invoice.destroy
    redirect_to admin_invoices_path, notice: "Invoice deleted."
  end

  def archive
    unless @invoice.status == "draft"
      redirect_to admin_invoice_path(@invoice), alert: "Only draft invoices can be archived."
      return
    end

    @invoice.archive!
    AuditLogger.log(
      user: current_user,
      action: "invoice_archived",
      auditable: @invoice
    )
    redirect_to admin_invoices_path, notice: "Invoice archived."
  end

  def preview_send
    @line_items = @invoice.line_items.includes(:app)
  end

  def send_to_stripe
    service = StripeInvoiceService.new(@invoice)
    service.create_and_send!

    AuditLogger.log(
      user: current_user,
      action: "invoice_sent_to_stripe",
      auditable: @invoice,
      changes_data: { stripe_invoice_id: @invoice.stripe_invoice_id }
    )

    redirect_to admin_invoice_path(@invoice), notice: "Invoice sent to Stripe."
  rescue StandardError => e
    redirect_to admin_invoice_path(@invoice), alert: "Stripe error: #{e.message}"
  end

  def mark_paid
    @invoice.update!(status: "paid")

    AuditLogger.log(
      user: current_user,
      action: "invoice_marked_paid",
      auditable: @invoice
    )

    redirect_to admin_invoice_path(@invoice), notice: "Invoice marked as paid."
  end

  def void_stripe
    unless @invoice.stripe_managed? && @invoice.status == "sent"
      redirect_to admin_invoice_path(@invoice), alert: "Only sent Stripe invoices can be voided."
      return
    end

    Stripe::Invoice.void_invoice(@invoice.stripe_invoice_id)
    @invoice.update!(status: "void", stripe_status: "void")

    AuditLogger.log(
      user: current_user,
      action: "invoice_voided_on_stripe",
      auditable: @invoice,
      changes_data: { stripe_invoice_id: @invoice.stripe_invoice_id }
    )

    redirect_to admin_invoice_path(@invoice), notice: "Invoice voided in Stripe."
  rescue Stripe::StripeError => e
    redirect_to admin_invoice_path(@invoice), alert: "Stripe error: #{e.message}"
  end

  def duplicate_as_draft
    new_invoice = Invoice.create!(
      client: @invoice.client,
      project: @invoice.project,
      bid: @invoice.bid,
      recurring_invoice: @invoice.recurring_invoice,
      invoice_type: @invoice.invoice_type,
      payment_type: @invoice.payment_type,
      period_start: @invoice.period_start,
      period_end: @invoice.period_end,
      subtotal: @invoice.subtotal,
      total: @invoice.total,
      final_amount: @invoice.final_amount,
      status: "draft"
    )

    @invoice.line_items.each do |li|
      new_invoice.line_items.create!(
        app_id: li.app_id,
        description: li.description,
        internal_cost: li.internal_cost,
        markup_percentage: li.markup_percentage,
        amount: li.amount,
        hours: li.hours,
        rate: li.rate
      )
    end

    AuditLogger.log(
      user: current_user,
      action: "invoice_duplicated_as_draft",
      auditable: new_invoice,
      changes_data: { original_invoice_id: @invoice.id }
    )

    redirect_to admin_invoice_path(new_invoice), notice: "Draft invoice ##{new_invoice.id} created from voided invoice ##{@invoice.id}. Review, edit if needed, and resend."
  end

  def sync_stripe
    unless Rails.env.development? || ENV["SKIP_AUTH"] == "true"
      redirect_to admin_invoice_path(@invoice), alert: "Sync is only available in development."
      return
    end

    unless @invoice.stripe_managed?
      redirect_to admin_invoice_path(@invoice), alert: "No Stripe invoice to sync."
      return
    end

    stripe_invoice = Stripe::Invoice.retrieve(@invoice.stripe_invoice_id)

    if stripe_invoice.status == "paid"
      paid_at = stripe_invoice.status_transitions.paid_at
      @invoice.update!(status: "paid", stripe_status: "paid", paid_at: paid_at ? Time.at(paid_at) : Time.current)
      redirect_to admin_invoice_path(@invoice), notice: "Synced — invoice is paid."
    else
      @invoice.update!(stripe_status: stripe_invoice.status)
      redirect_to admin_invoice_path(@invoice), notice: "Synced — Stripe status: #{stripe_invoice.status}."
    end
  rescue Stripe::StripeError => e
    redirect_to admin_invoice_path(@invoice), alert: "Stripe error: #{e.message}"
  end

  private

  def set_invoice
    @invoice = Invoice.find(params[:id])
  end

  def invoice_params
    params.require(:invoice).permit(:client_id, :period_start, :period_end, :status, :invoice_type,
      line_items_attributes: [:id, :app_id, :description, :internal_cost, :markup_percentage, :amount, :hours, :rate, :_destroy])
  end
end
