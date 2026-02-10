class Admin::TimeEntriesController < Admin::BaseController
  before_action :set_project
  before_action :set_time_entry, only: [:edit, :update, :destroy]

  def index
    @time_entries = @project.time_entries.includes(:user).order(entry_date: :desc, created_at: :desc)
    @hours_by_category = @project.hours_by_category
  end

  def new
    @time_entry = @project.time_entries.build(
      entry_date: Date.current,
      user: current_user
    )
  end

  def create
    @time_entry = @project.time_entries.build(time_entry_params)
    @time_entry.user = current_user

    if @time_entry.save
      redirect_to admin_project_path(@project), notice: "Time entry logged successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @time_entry.update(time_entry_params)
      redirect_to admin_project_path(@project), notice: "Time entry updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @time_entry.destroy
    redirect_to admin_project_path(@project), notice: "Time entry deleted."
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def set_time_entry
    @time_entry = @project.time_entries.find(params[:id])
  end

  def time_entry_params
    params.require(:time_entry).permit(:entry_date, :hours, :work_category, :notes)
  end
end
