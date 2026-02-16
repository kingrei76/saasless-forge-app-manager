class BillingPrepJob < ApplicationJob
  queue_as :default

  def perform
    clients = Client.where.not(stripe_subscription_id: nil)
      .where.not(stripe_customer_id: nil)

    Rails.logger.info("BillingPrepJob: Processing #{clients.count} subscription clients")

    results = { success: 0, errors: 0 }

    clients.find_each do |client|
      service = SubscriptionBillingService.new(client)
      service.sync_pending_items!
      results[:success] += 1
    rescue => e
      results[:errors] += 1
      Rails.logger.error("BillingPrepJob: Failed for #{client.name}: #{e.message}")
    end

    Rails.logger.info("BillingPrepJob: Done — #{results[:success]} succeeded, #{results[:errors]} errors")
  end
end
