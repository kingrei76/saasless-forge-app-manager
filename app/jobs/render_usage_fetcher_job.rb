class RenderUsageFetcherJob < ApplicationJob
  queue_as :default

  def perform(hours_back: 6)
    Rails.logger.info "Starting Render usage fetcher job (last #{hours_back} hours)..."

    fetcher = RenderUsageFetcher.new
    results = fetcher.fetch_all_apps(from: hours_back.hours.ago, to: Time.current)

    Rails.logger.info "Render usage fetcher completed: #{results.inspect}"
    results
  end
end
