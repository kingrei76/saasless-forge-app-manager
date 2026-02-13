class AiProviderService
  MODEL_PATTERNS = {
    /^gpt-/i     => "openai",
    /^o[1-9]/i   => "openai",     # o1, o3-mini, etc.
    /^claude-/i  => "anthropic",
    /^grok-/i    => "grok",
  }.freeze

  def self.resolve_provider(model)
    MODEL_PATTERNS.each do |pattern, slug|
      return ServiceProvider.find_by!(slug: slug) if model.match?(pattern)
    end
    raise "Unknown model: #{model}"
  end

  def self.forward_chat(provider:, body:)
    case provider.slug
    when "anthropic"
      forward_to_anthropic(provider, body)
    else
      forward_openai_compatible(provider, body)
    end
  end

  private

  def self.forward_openai_compatible(provider, body)
    uri = URI("#{provider.base_url}/chat/completions")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{provider.api_key}"
    request.body = body.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 120) do |http|
      http.request(request)
    end

    parsed = JSON.parse(response.body)
    { body: parsed, status: response.code.to_i, usage: parsed["usage"] }
  end

  def self.forward_to_anthropic(provider, body)
    raise "Anthropic proxy not yet implemented — add adapter when ready"
  end
end
