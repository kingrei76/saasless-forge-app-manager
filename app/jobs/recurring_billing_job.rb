class RecurringBillingJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info("RecurringBillingJob: Starting daily recurring billing run")

    results = RecurringBillingService.process_all_due

    success_count = results.count { |r| r[:success] }
    error_count = results.count { |r| !r[:success] }

    Rails.logger.info("RecurringBillingJob: Completed. #{success_count} succeeded, #{error_count} failed.")

    results.select { |r| !r[:success] }.each do |r|
      Rails.logger.error("RecurringBillingJob: Failed for #{r[:client]&.name}: #{r[:error]}")
    end
  end
end
