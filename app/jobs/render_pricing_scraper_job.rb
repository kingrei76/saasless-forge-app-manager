class RenderPricingScraperJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting Render pricing scraper job..."

    scraper = RenderPricingScraper.new
    results = scraper.scrape_and_update

    Rails.logger.info "Render pricing scraper completed: #{results.inspect}"
    results
  end
end
