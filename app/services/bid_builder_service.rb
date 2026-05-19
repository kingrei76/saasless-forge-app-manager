class BidBuilderService
  attr_reader :errors, :bid

  PERMITTED_BID_ATTRS = %w[
    title hourly_rate notes internal_notes
    requirements_summary project_scope ai_generated
  ].freeze

  def initialize(payload, user:)
    @payload = (payload || {}).deep_stringify_keys
    @user = user
    @errors = []
    @bid = nil
  end

  def call
    @errors = validate
    return { success: false, errors: @errors, status: error_status } if @errors.any?

    ActiveRecord::Base.transaction do
      build_bid!
      build_apps!
      build_features!
      build_monthly_costs!
      @bid.recalculate_total!
    end

    { success: true, bid: @bid }
  rescue ActiveRecord::RecordInvalid => e
    @errors = e.record.errors.full_messages
    { success: false, errors: @errors, status: :unprocessable_entity }
  end

  private

  def bid_attrs
    @bid_attrs ||= (@payload["bid"] || {})
  end

  def features
    @features ||= Array(bid_attrs["features"])
  end

  def monthly_costs
    @monthly_costs ||= Array(bid_attrs["monthly_costs"])
  end

  def app_refs
    @app_refs ||= Array(bid_attrs["apps"])
  end

  def error_status
    @error_status ||= :unprocessable_entity
  end

  def validate
    errs = []

    if bid_attrs.blank?
      errs << "bid payload is required"
      return errs
    end

    client_id = bid_attrs["client_id"]
    if client_id.blank?
      errs << "client_id is required"
    elsif !Client.exists?(id: client_id)
      errs << "client_id #{client_id} not found"
      @error_status = :not_found
    end

    errs << "title is required" if bid_attrs["title"].to_s.strip.empty?

    rate = bid_attrs["hourly_rate"]
    if rate.nil? || rate.to_s.strip.empty?
      errs << "hourly_rate must be finalized and > 0"
    else
      begin
        errs << "hourly_rate must be finalized and > 0" unless BigDecimal(rate.to_s) > 0
      rescue ArgumentError
        errs << "hourly_rate must be numeric"
      end
    end

    if features.empty?
      errs << "at least one feature is required"
    else
      features.each_with_index do |f, i|
        f = (f || {}).stringify_keys
        errs << "features[#{i}].description is required" if f["description"].to_s.strip.empty?
        hours = f["hours"]
        if hours.nil? || hours.to_f <= 0
          errs << "features[#{i}].hours must be > 0"
        end
        wc = f["work_category"]
        if wc.blank? || !BidLineItem::WORK_CATEGORIES.include?(wc)
          errs << "features[#{i}].work_category must be one of #{BidLineItem::WORK_CATEGORIES.join(', ')}"
        end
      end
    end

    monthly_costs.each_with_index do |c, i|
      c = (c || {}).stringify_keys
      errs << "monthly_costs[#{i}].description is required" if c["description"].to_s.strip.empty?
      unit_cost = c["unit_cost"]
      if unit_cost.nil? || unit_cost.to_f < 0
        errs << "monthly_costs[#{i}].unit_cost must be >= 0"
      end
      freq = c["billing_frequency"]
      if freq.present? && !BidLineItem::BILLING_FREQUENCIES.include?(freq)
        errs << "monthly_costs[#{i}].billing_frequency must be one of #{BidLineItem::BILLING_FREQUENCIES.join(', ')}"
      end
    end

    app_refs.each_with_index do |a, i|
      a = (a || {}).stringify_keys
      app_id = a["app_id"]
      new_name = a["new_app_name"].to_s.strip
      if app_id.blank? && new_name.empty?
        errs << "apps[#{i}] must provide either app_id or new_app_name"
      elsif app_id.present? && !App.exists?(id: app_id)
        errs << "apps[#{i}].app_id #{app_id} not found"
        @error_status = :not_found
      end
    end

    errs
  end

  def build_bid!
    attrs = bid_attrs.slice(*PERMITTED_BID_ATTRS)
    @bid = Bid.new(attrs)
    @bid.client_id = bid_attrs["client_id"]
    @bid.hourly_rate = bid_attrs["hourly_rate"]
    @bid.status = "draft"
    @bid.wizard_state ||= {}
    @bid.save!
  end

  def build_apps!
    app_refs.each do |a|
      a = (a || {}).stringify_keys
      @bid.bid_apps.create!(
        app_id: a["app_id"].presence,
        new_app_name: a["new_app_name"].to_s.strip.presence
      )
    end
  end

  def build_features!
    features.each_with_index do |f, idx|
      f = (f || {}).stringify_keys
      @bid.line_items.create!(
        line_item_type: "development",
        description: f["description"].to_s.strip,
        hours: f["hours"],
        rate: f["rate"].presence || @bid.hourly_rate,
        work_category: f["work_category"],
        position: idx
      )
    end
  end

  def build_monthly_costs!
    monthly_costs.each_with_index do |c, idx|
      c = (c || {}).stringify_keys
      @bid.line_items.create!(
        line_item_type: "system_cost",
        description: c["description"].to_s.strip,
        unit_cost: c["unit_cost"],
        is_recurring: c.fetch("is_recurring", true),
        billing_frequency: c["billing_frequency"].presence || "monthly",
        position: features.size + idx
      )
    end
  end
end
