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
  end

  def new
    @client = Client.new
  end

  def create
    @client = Client.new(client_params)

    if @client.save
      redirect_to admin_client_path(@client), notice: "Client created."
    else
      render :new, status: :unprocessable_entity
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
