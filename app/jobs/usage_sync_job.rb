class UsageSyncJob < ApplicationJob
  queue_as :default

  def perform(provider_id: nil)
    providers = provider_id ? ServiceProvider.where(id: provider_id) : ServiceProvider.active.syncable

    providers.find_each do |provider|
      sync_provider(provider)
    rescue => e
      Rails.logger.error("UsageSyncJob failed for #{provider.name}: #{e.message}")
    end
  end

  private

  def sync_provider(provider)
    adapter = provider.sync_adapter_class&.new(provider)
    return unless adapter

    since = provider.last_synced_at || 1.day.ago
    records = adapter.fetch_usage(since: since)

    records.each do |record|
      next if record[:external_id].present? && ApiUsageLog.exists?(external_id: record[:external_id])

      app = adapter.resolve_app(record)
      log = ApiUsageLog.new(
        app: app,
        service_provider: provider,
        provider: provider.slug,
        model: record[:model],
        operation: record[:operation],
        input_tokens: record[:input_tokens],
        output_tokens: record[:output_tokens],
        quantity: record[:quantity],
        quantity_unit: record[:quantity_unit],
        metadata: record[:metadata] || {},
        external_id: record[:external_id]
      )
      log.estimated_cost = provider.calculate_cost(record)
      log.save!
    end

    provider.update!(last_synced_at: Time.current)
  end
end
