class RenderPricingScraper
  # Hardcoded fallback prices as of 2024
  # These are used when scraping fails
  FALLBACK_PRICES = {
    web_service: {
      "free" => { monthly: 0, bandwidth_gb: 100 },
      "starter" => { monthly: 7, bandwidth_gb: 100 },
      "standard" => { monthly: 25, bandwidth_gb: 100 },
      "pro" => { monthly: 85, bandwidth_gb: 100 },
      "pro_plus" => { monthly: 175, bandwidth_gb: 100 },
      "pro_max" => { monthly: 225, bandwidth_gb: 100 },
      "pro_ultra" => { monthly: 450, bandwidth_gb: 100 }
    },
    postgres: {
      "free" => { monthly: 0, storage_gb: 1 },
      "basic_256mb" => { monthly: 6, storage_gb: 1 },
      "basic_1gb" => { monthly: 19, storage_gb: 16 },
      "basic_4gb" => { monthly: 75, storage_gb: 64 },
      "pro_4gb" => { monthly: 55, storage_gb: 64 },
      "pro_8gb" => { monthly: 100, storage_gb: 128 },
      "pro_16gb" => { monthly: 200, storage_gb: 256 },
      "pro_32gb" => { monthly: 400, storage_gb: 512 }
    },
    redis: {
      "free" => { monthly: 0 },
      "starter" => { monthly: 10 },
      "standard" => { monthly: 40 },
      "pro" => { monthly: 95 }
    },
    cron_job: {
      "free" => { monthly: 0 },
      "starter" => { monthly: 1 }
    },
    static_site: {
      "free" => { monthly: 0 },
      "starter" => { monthly: 0 }
    }
  }.freeze

  BANDWIDTH_OVERAGE_PER_GB = 0.10  # $0.10 per GB over included
  STORAGE_OVERAGE_PER_GB = 0.25   # $0.25 per GB over included
  DISK_PRICE_PER_GB_MONTHLY = 0.30  # ~$0.0004/hr per GB disk storage

  def initialize
    @effective_from = Date.current
  end

  def scrape_and_update
    # Attempt to scrape live prices - for now, use fallback
    # In production, you would scrape https://render.com/pricing
    update_prices_from_fallback
  end

  def seed_default_prices
    update_prices_from_fallback
  end

  private

  def update_prices_from_fallback
    results = { created: 0, updated: 0 }

    FALLBACK_PRICES.each do |service_type, plans|
      plans.each do |plan_name, pricing|
        price = RenderPrice.find_or_initialize_by(
          service_type: service_type.to_s,
          plan_name: plan_name,
          effective_from: @effective_from
        )

        was_new = price.new_record?

        price.assign_attributes(
          monthly_price: pricing[:monthly],
          bandwidth_overage_per_gb: BANDWIDTH_OVERAGE_PER_GB,
          storage_overage_per_gb: STORAGE_OVERAGE_PER_GB,
          included_bandwidth_gb: pricing[:bandwidth_gb],
          included_storage_gb: pricing[:storage_gb],
          effective_until: nil
        )

        if price.save
          was_new ? results[:created] += 1 : results[:updated] += 1
        end
      end
    end

    results
  end

  def scrape_render_pricing_page
    # Future implementation: Use Nokogiri to scrape https://render.com/pricing
    # For now, return nil to trigger fallback
    nil
  rescue => e
    Rails.logger.error "Failed to scrape Render pricing: #{e.message}"
    nil
  end
end
