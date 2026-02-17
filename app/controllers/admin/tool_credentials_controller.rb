class Admin::ToolCredentialsController < Admin::BaseController
  before_action :set_tool
  before_action :set_credential, only: [:update, :destroy]

  def create
    @credential = @tool.tool_credentials.build(credential_params)

    if @credential.save
      redirect_to admin_tool_definition_path(@tool), notice: "Credential added."
    else
      redirect_to admin_tool_definition_path(@tool), alert: "Failed to add credential: #{@credential.errors.full_messages.join(', ')}"
    end
  end

  def update
    # Don't overwrite credential value with empty/placeholder
    filtered = credential_params.to_h
    filtered.delete("encrypted_value") if filtered["encrypted_value"].blank?

    if @credential.update(filtered)
      redirect_to admin_tool_definition_path(@tool), notice: "Credential updated."
    else
      redirect_to admin_tool_definition_path(@tool), alert: "Failed to update credential."
    end
  end

  def destroy
    @credential.destroy
    redirect_to admin_tool_definition_path(@tool), notice: "Credential deleted."
  end

  private

  def set_tool
    @tool = ToolDefinition.find(params[:tool_definition_id])
  end

  def set_credential
    @credential = @tool.tool_credentials.find(params[:id])
  end

  def credential_params
    params.require(:tool_credential).permit(:name, :credential_type, :encrypted_value, :expires_at, :status)
  end
end
