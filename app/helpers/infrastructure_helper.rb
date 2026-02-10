module InfrastructureHelper
  OPERATION_LABELS = {
    "generate_clarifying_questions" => "Generate Clarifying Questions",
    "generate_bid_details" => "Generate Bid Details",
    "generate_line_items" => "Generate Line Items",
    "suggest_costs" => "Suggest Costs",
    "analyze_requirements" => "Analyze Requirements",
    "estimate_timeline" => "Estimate Timeline"
  }.freeze

  def operation_label(operation)
    OPERATION_LABELS[operation] || operation.to_s.titleize
  end

  def period_label(period)
    case period
    when "this_month"
      "This Month"
    when "last_month"
      "Last Month"
    when "all_time"
      "All Time"
    else
      period.to_s.titleize
    end
  end

  def format_tokens(tokens)
    return "0" if tokens.nil? || tokens.zero?

    if tokens >= 1_000_000
      "#{(tokens / 1_000_000.0).round(2)}M"
    elsif tokens >= 1_000
      "#{(tokens / 1_000.0).round(1)}K"
    else
      tokens.to_s
    end
  end
end
