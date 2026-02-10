class Admin::AppAssignmentsController < Admin::BaseController
  before_action :require_admin!
  before_action :set_client

  def create
    @assignment = @client.app_assignments.build(app_assignment_params)

    if @assignment.save
      redirect_to admin_client_path(@client), notice: "App assigned."
    else
      redirect_to admin_client_path(@client), alert: @assignment.errors.full_messages.join(", ")
    end
  end

  def update
    @assignment = @client.app_assignments.find(params[:id])

    if @assignment.update(app_assignment_params)
      redirect_to admin_client_path(@client), notice: "Assignment updated."
    else
      redirect_to admin_client_path(@client), alert: @assignment.errors.full_messages.join(", ")
    end
  end

  def destroy
    @assignment = @client.app_assignments.find(params[:id])
    @assignment.destroy
    redirect_to admin_client_path(@client), notice: "App unassigned."
  end

  private

  def set_client
    @client = Client.find(params[:client_id])
  end

  def app_assignment_params
    params.require(:app_assignment).permit(:app_id, :markup_percentage)
  end
end
