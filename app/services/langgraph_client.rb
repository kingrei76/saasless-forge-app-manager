class LanggraphClient
  class ServiceError < StandardError; end

  def initialize
    @base_url = Setting[:langgraph_service_url] || ENV["LANGGRAPH_SERVICE_URL"] || "http://localhost:8100"
    @auth_token = Setting[:langgraph_auth_token] || ENV["LANGGRAPH_AUTH_TOKEN"]
  end

  def execute_agent(agent, input_data: {})
    execution = AgentExecution.create!(
      agent: agent,
      status: "pending",
      mode: agent.mode,
      input_data: input_data
    )

    payload = build_execution_payload(agent, execution, input_data)

    response = post("/agents/execute", payload)
    execution.update!(status: "running", started_at: Time.current)

    execution
  rescue => e
    execution&.update(status: "failed", error_message: e.message, completed_at: Time.current)
    raise ServiceError, "Failed to start execution: #{e.message}"
  end

  def get_execution_status(execution_id)
    get("/executions/#{execution_id}")
  end

  def approve_step(execution_id, step_number)
    post("/executions/#{execution_id}/approve", { step_number: step_number })
  end

  def reject_step(execution_id, step_number)
    post("/executions/#{execution_id}/reject", { step_number: step_number })
  end

  def stop_execution(execution_id)
    post("/executions/#{execution_id}/stop", {})
  end

  def execute_chat(agent, execution, message, memory, system_prompt, context_data = {})
    payload = build_chat_payload(agent, execution, message, memory, system_prompt, context_data)
    response = post("/agents/execute", payload)
    execution.update!(status: "running", started_at: Time.current)
    response
  end

  def health_check
    get("/health")
  rescue => e
    { status: "error", message: e.message }
  end

  private

  def build_chat_payload(agent, execution, message, memory, system_prompt, context_data = {})
    agent_tools = agent.agent_tools.enabled.includes(:tool_definition)

    tools = agent_tools.map do |at|
      td = at.tool_definition
      {
        name: td.slug,
        description: td.description,
        requires_approval: at.requires_approval
      }
    end

    approval_required_tools = agent_tools.select(&:requires_approval).map { |at| at.tool_definition.slug }

    callback_base = Setting[:app_base_url] || ENV["APP_BASE_URL"] || "http://localhost:3000"
    gateway_url = Setting[:gateway_service_url] || ENV["GATEWAY_SERVICE_URL"]
    gateway_token = Setting[:gateway_auth_token] || ENV["GATEWAY_AUTH_TOKEN"]
    model_name = agent.ai_model&.model_id || agent.llm_model || "grok-3"

    metadata = {}
    if gateway_url.present?
      metadata[:gateway_url] = gateway_url
      metadata[:gateway_token] = gateway_token
    end

    {
      execution_id: execution.id.to_s,
      agent_config: {
        agent_id: agent.id.to_s,
        name: agent.name,
        system_prompt: system_prompt,
        model: model_name,
        temperature: agent.temperature.to_f,
        max_steps: agent.max_iterations || 20,
        tools: tools,
        approval_required_tools: approval_required_tools,
        metadata: metadata
      },
      input_message: message,
      memory: memory,
      mode: agent.mode,
      callback_url: "#{callback_base}/api/agent_callbacks",
      context: {
        host_app_url: callback_base,
        host_app_token: @auth_token || "",
        target_agent_id: context_data[:target_agent_id]
      }.compact
    }
  end

  def build_execution_payload(agent, execution, input_data)
    agent_tools_rel = agent.agent_tools.enabled.includes(:tool_definition)

    tools = agent_tools_rel.map do |at|
      td = at.tool_definition
      {
        name: td.slug,
        description: td.description,
        requires_approval: at.requires_approval
      }
    end

    approval_required_tools = agent_tools_rel.select(&:requires_approval).map { |at| at.tool_definition.slug }

    callback_base = Setting[:app_base_url] || ENV["APP_BASE_URL"] || "http://localhost:3000"
    gateway_url = Setting[:gateway_service_url] || ENV["GATEWAY_SERVICE_URL"]
    gateway_token = Setting[:gateway_auth_token] || ENV["GATEWAY_AUTH_TOKEN"]
    model_name = agent.ai_model&.model_id || agent.llm_model || "grok-3"

    metadata = {}
    if gateway_url.present?
      metadata[:gateway_url] = gateway_url
      metadata[:gateway_token] = gateway_token
    end

    {
      execution_id: execution.id.to_s,
      agent_config: {
        agent_id: agent.id.to_s,
        name: agent.name,
        system_prompt: agent.system_prompt,
        model: model_name,
        temperature: agent.temperature.to_f,
        max_steps: agent.max_iterations || 20,
        tools: tools,
        approval_required_tools: approval_required_tools,
        metadata: metadata
      },
      input_message: input_data.is_a?(Hash) ? (input_data[:message] || input_data.to_json) : input_data.to_s,
      mode: agent.mode,
      callback_url: "#{callback_base}/api/agent_callbacks",
      context: {
        host_app_url: callback_base,
        host_app_token: @auth_token || ""
      }
    }
  end

  def get(path)
    uri = URI("#{@base_url}#{path}")
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{@auth_token}" if @auth_token.present?
    request["Content-Type"] = "application/json"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.open_timeout = 10
      http.read_timeout = 30
      http.request(request)
    end

    handle_response(response)
  end

  def post(path, body)
    uri = URI("#{@base_url}#{path}")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{@auth_token}" if @auth_token.present?
    request["Content-Type"] = "application/json"
    request.body = body.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.open_timeout = 10
      http.read_timeout = 120
      http.request(request)
    end

    handle_response(response)
  end

  def handle_response(response)
    case response.code.to_i
    when 200..299
      JSON.parse(response.body) rescue response.body
    when 401
      raise ServiceError, "Authentication failed - check LANGGRAPH_AUTH_TOKEN"
    when 404
      raise ServiceError, "Endpoint not found"
    else
      body = JSON.parse(response.body) rescue { "detail" => response.body }
      raise ServiceError, "Service error (#{response.code}): #{body['detail'] || body}"
    end
  end
end
