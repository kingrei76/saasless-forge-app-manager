class MonthlyInfrastructureBillingJob < ApplicationJob
  queue_as :default

  def perform(billing_period_start: nil, billing_period_end: nil)
    billing_period_start ||= Date.current.beginning_of_month
    billing_period_end ||= Date.current.end_of_month

    results = MonthlyInfrastructureBillingService.generate_for_all_clients(
      billing_period_start: billing_period_start,
      billing_period_end: billing_period_end
    )

    success_count = results.count { |r| r[:success] }
    error_count = results.count { |r| !r[:success] }

    Rails.logger.info "[MonthlyInfrastructureBillingJob] Generated #{success_count} invoice(s), #{error_count} failed"

    results.each do |result|
      if result[:success]
        Rails.logger.info "  - #{result[:client].name}: Invoice ##{result[:invoice].id} created"
      else
        Rails.logger.warn "  - #{result[:client].name}: #{result[:error]}"
      end
    end

    { success_count: success_count, error_count: error_count, results: results }
  end
end
