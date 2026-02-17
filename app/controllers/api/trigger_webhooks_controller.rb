class Api::TriggerWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!

  def create
    payload = JSON.parse(request.body.read) rescue {}

    execution = AgentTriggerService.fire_webhook(params[:webhook_token], payload)

    if execution
      render json: { status: "ok", execution_id: execution.id }, status: :ok
    else
      render json: { error: "not_found" }, status: :not_found
    end
  end
end
