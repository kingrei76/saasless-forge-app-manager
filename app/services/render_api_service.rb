class RenderApiService
  BASE_URL = "https://api.render.com/v1"

  def initialize(api_key: nil)
    @api_key = api_key || Setting[:render_api_key]
    raise ArgumentError, "Render API key is not configured" if @api_key.blank?
  end

  def test_connection
    response = get("/owners")
    { success: true, owner: response.first&.dig("owner", "name") || "Connected" }
  rescue => e
    { success: false, error: e.message }
  end

  def list_services
    services = []
    cursor = nil

    loop do
      path = "/services?limit=100"
      path += "&cursor=#{cursor}" if cursor
      batch = get(path)
      break if batch.empty?

      services.concat(batch.map { |item| item["service"] })
      cursor = batch.last&.dig("cursor")
      break if cursor.nil? || batch.size < 100
    end

    services
  end

  def get_service(service_id)
    get("/services/#{service_id}")
  end

  def list_postgres
    databases = []
    cursor = nil

    loop do
      path = "/postgres?limit=100"
      path += "&cursor=#{cursor}" if cursor
      batch = get(path)
      break if batch.empty?

      databases.concat(batch.map { |item| item["postgres"] })
      cursor = batch.last&.dig("cursor")
      break if cursor.nil? || batch.size < 100
    end

    databases
  end

  def get_postgres(postgres_id)
    get("/postgres/#{postgres_id}")
  end

  # Owner/Workspace methods
  def list_owners
    get("/owners")
  end

  def get_owner(owner_id)
    get("/owners/#{owner_id}")
  end

  # Metrics methods - Note: Render's metrics API may require specific permissions
  # These fetch CPU, memory, and bandwidth usage for services

  def get_cpu_metrics(service_id, from:, to:, resolution: "1h")
    get_metrics(service_id, metric: "cpu", from: from, to: to, resolution: resolution)
  end

  def get_memory_metrics(service_id, from:, to:, resolution: "1h")
    get_metrics(service_id, metric: "memory", from: from, to: to, resolution: resolution)
  end

  def get_bandwidth_metrics(service_id, from:, to:, resolution: "1h")
    get_metrics(service_id, metric: "bandwidth", from: from, to: to, resolution: resolution)
  end

  def get_metrics(service_id, metric:, from:, to:, resolution: "1h")
    # Convert times to ISO8601 format
    from_str = from.is_a?(Time) ? from.iso8601 : from.to_time.iso8601
    to_str = to.is_a?(Time) ? to.iso8601 : to.to_time.iso8601

    path = "/services/#{service_id}/metrics/#{metric}?from=#{CGI.escape(from_str)}&to=#{CGI.escape(to_str)}&resolution=#{resolution}"
    get(path)
  rescue => e
    Rails.logger.warn "Failed to fetch #{metric} metrics for #{service_id}: #{e.message}"
    []
  end

  # Billing/Usage - if available in Render API
  def get_billing_info
    get("/billing")
  rescue => e
    Rails.logger.warn "Billing API not available: #{e.message}"
    nil
  end

  private

  def get(path)
    uri = URI("#{BASE_URL}#{path}")
    request = Net::HTTP::Get.new(uri)
    request["Accept"] = "application/json"
    request["Authorization"] = "Bearer #{@api_key}"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) do |http|
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      raise "Render API error: #{response.code} #{response.message}"
    end

    JSON.parse(response.body)
  end
end
