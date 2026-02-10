class StripeBillingSyncJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting Stripe billing sync job..."

    service = StripeBillingCycleService.new
    results = service.sync_all_clients

    Rails.logger.info "Stripe billing sync completed: #{results.inspect}"
    results
  end
end
