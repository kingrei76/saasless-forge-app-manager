class Admin::ProjectsController < Admin::BaseController
  before_action :set_project, only: [:show, :edit, :update, :destroy, :upload_requirements, :upload_signed_contract, :advance_stage, :complete, :link_app, :unlink_app]

  def index
    @projects = Project.includes(:client, :assignee).order(created_at: :desc)
    @projects = @projects.by_status(params[:status]) if params[:status].present?
    @projects = @projects.by_stage(params[:stage]) if params[:stage].present?
  end

  def show
    @bids = @project.bids.order(created_at: :desc)
    @invoices = @project.invoices.order(created_at: :desc)
    @time_entries = @project.time_entries.includes(:user).order(entry_date: :desc).limit(5)
    @hours_by_category = @project.hours_by_category
    @users = User.order(:name)
    @project_apps = @project.project_apps.includes(:app)
    @available_apps = App.included.where.not(id: @project.app_ids).order(:name)
    @commits = @project.has_linked_app? ? @project.recent_commits(limit: 10) : []
  end

  def edit
    @clients = Client.order(:name)
    @users = User.order(:name)
  end

  def update
    if @project.update(project_params)
      redirect_to admin_project_path(@project), notice: "Project updated."
    else
      @clients = Client.order(:name)
      @users = User.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project.destroy
    redirect_to admin_projects_path, notice: "Project deleted."
  end

  def upload_requirements
    if params[:requirements_doc].present?
      @project.requirements_doc.attach(params[:requirements_doc])
      redirect_to admin_project_path(@project), notice: "Requirements doc uploaded."
    else
      redirect_to admin_project_path(@project), alert: "No file selected."
    end
  end

  def upload_signed_contract
    if params[:signed_contract].present?
      @project.signed_contract.attach(params[:signed_contract])
      redirect_to admin_project_path(@project), notice: "Signed contract uploaded."
    else
      redirect_to admin_project_path(@project), alert: "No file selected."
    end
  end

  def advance_stage
    if @project.advance_stage!
      redirect_to admin_project_path(@project), notice: "Project advanced to #{@project.stage_label}."
    else
      redirect_to admin_project_path(@project), alert: "Cannot advance stage."
    end
  end

  def complete
    result = ProjectCompletionService.new(@project).call

    if result[:success]
      redirect_to admin_project_path(@project),
                  notice: "Project completed! Final invoice created."
    else
      redirect_to admin_project_path(@project), alert: "Error: #{result[:error]}"
    end
  end

  def link_app
    app = App.find(params[:app_id])

    # Check if there's a pending app to link
    pending_app = @project.project_apps.pending_creation.find_by(id: params[:project_app_id])

    if pending_app
      pending_app.link_to_app!(app)
      redirect_to admin_project_path(@project), notice: "App linked to project."
    else
      @project.project_apps.create!(app: app, primary: @project.project_apps.empty?)
      redirect_to admin_project_path(@project), notice: "App added to project."
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_project_path(@project), alert: "Failed to link app: #{e.message}"
  end

  def unlink_app
    project_app = @project.project_apps.find(params[:project_app_id])
    project_app.destroy
    redirect_to admin_project_path(@project), notice: "App removed from project."
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:client_id, :title, :description, :status, :stage,
                                    :assignee_id, :development_due_date, :go_live_date,
                                    :adoption_due_date, :estimated_hours)
  end
end
