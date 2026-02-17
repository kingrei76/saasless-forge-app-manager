class Admin::ToolVersionsController < Admin::BaseController
  def index
    @tool = ToolDefinition.find(params[:tool_definition_id])
    @versions = @tool.tool_versions.ordered
  end
end
