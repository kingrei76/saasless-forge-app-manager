class Admin::RecurringInvoicesController < Admin::BaseController
  include ActionView::Helpers::NumberHelper
  before_action :require_admin!
  before_action :set_recurring_invoice, only: [:show, :edit, :update, :destroy, :activate, :pause, :cancel, :setup_payment_method, :send_payment_setup, :migrate_to_subscription]

  def index
    RecurringInvoice.ensure_for_billable_clients!
    @recurring_invoices = RecurringInvoice.includes(:client, :invoices, client: { app_assignments: { app: :render_services } }).order(created_at: :desc)
  end

  def show
    @invoices = @recurring_invoice.invoices.order(created_at: :desc)
  end

  def new
    @recurring_invoice = RecurringInvoice.new
    @available_clients = Client.where.not(id: RecurringInvoice.select(:client_id)).order(:name)
  end

  def create
    @recurring_invoice = RecurringInvoice.new(recurring_invoice_params)

    if @recurring_invoice.save
      redirect_to admin_recurring_invoice_path(@recurring_invoice), notice: "Recurring invoice created."
    else
      @available_clients = Client.where.not(id: RecurringInvoice.select(:client_id)).order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @available_clients = Client.where.not(id: RecurringInvoice.where.not(id: @recurring_invoice.id).select(:client_id)).order(:name)
  end

  def update
    if @recurring_invoice.update(recurring_invoice_params)
      redirect_to admin_recurring_invoice_path(@recurring_invoice), notice: "Recurring invoice updated."
    else
      @available_clients = Client.where.not(id: RecurringInvoice.where.not(id: @recurring_invoice.id).select(:client_id)).order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @recurring_invoice.destroy
    redirect_to admin_recurring_invoices_path, notice: "Recurring invoice deleted."
  end

  def activate
    @recurring_invoice.activate!
    AuditLogger.log(user: current_user, action: "recurring_invoice_activated", auditable: @recurring_invoice)
    redirect_to admin_recurring_invoice_path(@recurring_invoice), notice: "Recurring billing activated. Next billing: #{@recurring_invoice.next_billing_date}."
  rescue => e
    redirect_to admin_recurring_invoice_path(@recurring_invoice), alert: "Failed to activate: #{e.message}"
  end

  def pause
    @recurring_invoice.pause!
    AuditLogger.log(user: current_user, action: "recurring_invoice_paused", auditable: @recurring_invoice)
    redirect_to admin_recurring_invoice_path(@recurring_invoice), notice: "Recurring billing paused."
  end

  def cancel
    @recurring_invoice.cancel!
    AuditLogger.log(user: current_user, action: "recurring_invoice_cancelled", auditable: @recurring_invoice)
    redirect_to admin_recurring_invoice_path(@recurring_invoice), notice: "Recurring billing cancelled."
  end

  def setup_payment_method
    client = @recurring_invoice.client
    service = StripePaymentMethodService.new(client)

    session = service.create_setup_session(
      success_url: admin_recurring_invoice_url(@recurring_invoice, payment_setup: "success"),
      cancel_url: admin_recurring_invoice_url(@recurring_invoice, payment_setup: "cancelled")
    )

    redirect_to session.url, allow_other_host: true
  rescue Stripe::StripeError => e
    redirect_to admin_recurring_invoice_path(@recurring_invoice), alert: "Stripe error: #{e.message}"
  end

  def migrate_to_subscription
    client = @recurring_invoice.client

    service = StripeSubscriptionSetupService.new(client)
    subscription = service.create_subscription!

    # Pause the old recurring invoice so both systems don't bill
    @recurring_invoice.pause! if @recurring_invoice.active?

    AuditLogger.log(
      user: current_user,
      action: "migrated_to_subscription_billing",
      auditable: @recurring_invoice,
      changes_data: {
        client: client.name,
        subscription_id: subscription.id
      }
    )

    redirect_to admin_recurring_invoice_path(@recurring_invoice),
      notice: "#{client.name} migrated to subscription billing! Subscription #{subscription.id} created. Old recurring invoice paused."
  rescue Stripe::StripeError => e
    redirect_to admin_recurring_invoice_path(@recurring_invoice), alert: "Stripe error: #{e.message}"
  rescue StandardError => e
    redirect_to admin_recurring_invoice_path(@recurring_invoice), alert: "Error: #{e.message}"
  end

  def send_payment_setup
    client = @recurring_invoice.client

    # Generate the real infrastructure invoice for the current period
    billing_service = MonthlyInfrastructureBillingService.new(client)
    result = billing_service.call

    unless result[:success]
      redirect_to admin_recurring_invoice_path(@recurring_invoice), alert: "Could not generate invoice: #{result[:error]}"
      return
    end

    invoice = result[:invoice]
    invoice.update!(recurring_invoice: @recurring_invoice)

    # Send via Stripe — customer gets emailed the real invoice
    stripe_service = StripeInvoiceService.new(invoice)
    stripe_service.create_and_send!

    # Also create the subscription (anchored to 1st of next month) so
    # automatic billing kicks in after this first invoice is paid
    subscription_notice = ""
    if client.stripe_subscription_id.blank? && Setting[:stripe_billing_price_id].present?
      begin
        sub_service = StripeSubscriptionSetupService.new(client)
        subscription = sub_service.create_subscription!
        @recurring_invoice.pause! if @recurring_invoice.active?
        subscription_notice = " Subscription #{subscription.id} created — automatic billing starts next month."
      rescue => e
        Rails.logger.error("Failed to create subscription for #{client.name}: #{e.message}")
        subscription_notice = " (Subscription setup failed: #{e.message} — you can retry via 'Migrate to Subscription')"
      end
    end

    AuditLogger.log(
      user: current_user,
      action: "initial_invoice_sent",
      auditable: invoice,
      changes_data: {
        client: client.name,
        email: client.email,
        stripe_invoice_id: invoice.stripe_invoice_id,
        total: invoice.total.to_f,
        subscription_id: client.stripe_subscription_id
      }
    )

    redirect_to admin_recurring_invoice_path(@recurring_invoice),
      notice: "Invoice for #{number_to_currency(invoice.total)} sent to #{client.email}.#{subscription_notice}"
  rescue Stripe::StripeError => e
    redirect_to admin_recurring_invoice_path(@recurring_invoice), alert: "Stripe error: #{e.message}"
  rescue StandardError => e
    redirect_to admin_recurring_invoice_path(@recurring_invoice), alert: "Error: #{e.message}"
  end

  private

  def set_recurring_invoice
    @recurring_invoice = RecurringInvoice.find(params[:id])
  end

  def recurring_invoice_params
    params.require(:recurring_invoice).permit(
      :client_id, :collection_method, :days_until_due,
      :billing_day_of_month, :notes
    )
  end
end
