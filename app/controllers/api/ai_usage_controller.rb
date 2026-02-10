class Api::AiUsageController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!, if: -> { defined?(super) }
  before_action :authenticate_api_request

  def create
    app = App.find_by!(ai_api_key: params[:api_key])

    log = ApiUsageLog.new(
      app: app,
      provider: params[:provider] || app.ai_api_provider || "grok",
      model: params[:model],
      operation: params[:operation],
      input_tokens: params[:input_tokens],
      output_tokens: params[:output_tokens]
    )
    log.calculate_cost!
    log.save!

    render json: { success: true, log_id: log.id, cost: log.estimated_cost }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Invalid API key" }, status: :unauthorized
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def authenticate_api_request
    unless params[:api_key].present?
      render json: { error: "API key required" }, status: :unauthorized
    end
  end
end
