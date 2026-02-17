class Admin::ToolDefinitionsController < Admin::BaseController
  before_action :set_tool, only: [:show, :update, :destroy]

  def index
    @tools = ToolDefinition.all
    @tools = @tools.by_category(params[:category]) if params[:category].present?
    @tools = @tools.where(status: params[:status]) if params[:status].present?
    @tools = @tools.where("tool_definitions.name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
    @tools = @tools.order(:category, :name)
  end

  def show
    @credentials = @tool.tool_credentials.order(:name)
    @versions = @tool.tool_versions.ordered
    @agents_using = @tool.agents.order(:name)
    @usage_count = AgentExecutionStep.where(tool_definition: @tool).count
  end

  def update
    if @tool.update(tool_params)
      AgentVersionService.snapshot_tool!(@tool, current_user, params[:change_summary])
      redirect_to admin_tool_definition_path(@tool), notice: "Tool updated."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def destroy
    AuditLogger.log(user: current_user, action: "tool.destroy", auditable: @tool)
    @tool.destroy
    redirect_to admin_tool_definitions_path, notice: "Tool definition deleted."
  end

  private

  def set_tool
    @tool = ToolDefinition.find(params[:id])
  end

  def tool_params
    params.require(:tool_definition).permit(:description, :risk_level, :status)
  end
end
