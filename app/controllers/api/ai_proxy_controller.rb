class Api::AiProxyController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  skip_before_action :authenticate_user_from_token!
  before_action :authenticate_app

  # POST /api/ai/v1/chat/completions
  def chat_completions
    provider = AiProviderService.resolve_provider(request_body_json["model"])
    return if performed? # authorize_service! may have rendered
    authorize_service!(provider)
    return if performed?

    response = AiProviderService.forward_chat(
      provider: provider,
      body: request_body_json
    )

    log_usage(response, provider)
    render json: response[:body], status: response[:status]
  rescue => e
    render json: { error: { message: e.message } }, status: :bad_gateway
  end

  # GET /api/ai/v1/models
  def models
    providers = @app.service_providers.active.where(proxy_enabled: true).by_category("llm")
    model_list = providers.flat_map { |p| p.pricing_rules.dig("models")&.keys || [] }
    render json: { data: model_list.map { |m| { id: m, object: "model" } } }
  end

  private

  def authenticate_app
    token = request.headers["Authorization"]&.sub(/^Bearer\s+/, "")
    @app = App.find_by(ai_api_key: token) if token.present?
    render json: { error: { message: "Invalid API key" } }, status: :unauthorized unless @app
  end

  def authorize_service!(provider)
    config = @app.app_service_configs.enabled.find_by(service_provider: provider)
    unless config
      render json: { error: { message: "App not authorized for #{provider.name}" } }, status: :forbidden
      return
    end
    if config.monthly_budget_limit.present?
      current_spend = @app.api_usage_logs.where(service_provider: provider).this_month.sum(:estimated_cost)
      if current_spend >= config.monthly_budget_limit
        render json: { error: { message: "Monthly budget limit reached" } }, status: :too_many_requests
      end
    end
  end

  def request_body_json
    @request_body_json ||= JSON.parse(request.body.read)
  end

  def log_usage(response, provider)
    return unless response[:usage].present?
    usage = response[:usage]

    log = ApiUsageLog.new(
      app: @app,
      service_provider: provider,
      provider: provider.slug,
      model: request_body_json["model"],
      operation: "chat_completion",
      input_tokens: usage["prompt_tokens"],
      output_tokens: usage["completion_tokens"]
    )
    log.estimated_cost = provider.calculate_cost(
      model: request_body_json["model"],
      input_tokens: usage["prompt_tokens"],
      output_tokens: usage["completion_tokens"]
    )
    log.save!
  end
end
