class Admin::ClientsController < Admin::BaseController
  before_action :require_admin!
  before_action :set_client, only: [:show, :edit, :update, :destroy]

  def index
    @clients = Client.order(:name)
  end

  def show
    @app_assignments = @client.app_assignments.includes(:app)
    @available_apps = App.included.where.not(id: @client.app_ids)

    # Bids summary
    @bids = @client.bids.order(created_at: :desc)
    @bids_by_status = @client.bids.group(:status).count

    # Projects summary
    @projects = @client.projects.includes(:assignee).order(created_at: :desc)
    @active_projects = @projects.in_progress
    @completed_projects = @projects.completed

    # Hours comparison for completed projects
    @hours_accuracy = calculate_hours_accuracy(@completed_projects)

    # Invoices summary
    @project_invoices = @client.invoices.project_invoices.order(created_at: :desc)
    @infrastructure_invoices = @client.invoices.infrastructure.order(created_at: :desc)
    @outstanding_balance = @client.invoices.where(status: %w[draft sent]).sum(:total)

    # Current billing cycle usage (for subscription clients)
    if @client.has_stripe_subscription?
      period_start, period_end = @client.current_billing_period
      cycle_id = period_start.strftime("%Y-%m")
      @pending_items = @client.pending_billing_items.pending.for_cycle(cycle_id).includes(:app)
      @cycle_total = @pending_items.sum(:billed_amount)
      @cycle_internal_total = @pending_items.sum(:internal_cost)
      @billing_period = [period_start, period_end]
    end
  end

  def new
    @client = Client.new
  end

  def create
    @client = Client.new(client_params)

    if @client.save
      respond_to do |format|
        format.html { redirect_to admin_client_path(@client), notice: "Client created." }
        format.json { render json: { success: true, client: { id: @client.id, name: @client.name } } }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { success: false, errors: @client.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def edit; end

  def update
    if @client.update(client_params)
      redirect_to admin_client_path(@client), notice: "Client updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @client.destroy
    redirect_to admin_clients_path, notice: "Client deleted."
  end

  private

  def set_client
    @client = Client.find(params[:id])
  end

  def client_params
    params.require(:client).permit(:name, :email, :company, :stripe_customer_id, :markup_percentage, :collection_method)
  end

  def calculate_hours_accuracy(projects)
    projects_with_estimates = projects.where.not(estimated_hours: nil).where("estimated_hours > 0")
    return nil if projects_with_estimates.empty?

    total_estimated = projects_with_estimates.sum(:estimated_hours)
    total_actual = projects_with_estimates.sum(:actual_hours)

    return nil if total_estimated.zero?

    ((total_actual - total_estimated) / total_estimated * 100).round(1)
  end
end
