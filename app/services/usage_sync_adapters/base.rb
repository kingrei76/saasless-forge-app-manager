module UsageSyncAdapters
  class Base
    attr_reader :provider

    def initialize(service_provider)
      @provider = service_provider
    end

    # Returns array of usage record hashes:
    # [{ external_id:, app_identifier:, model:, operation:,
    #    input_tokens:, output_tokens:, quantity:, quantity_unit:,
    #    metadata:, recorded_at: }]
    def fetch_usage(since:, until_date: Time.current)
      raise NotImplementedError, "#{self.class} must implement #fetch_usage"
    end

    # Resolves a usage record to an App via AppServiceConfig.external_identifier
    def resolve_app(record)
      return nil unless record[:app_identifier].present?
      config = provider.app_service_configs.enabled.find_by(external_identifier: record[:app_identifier])
      config&.app
    end

    private

    def api_key
      provider.api_key
    end

    def usage_api_key
      provider.usage_api_key.presence || provider.api_key
    end
  end
end
