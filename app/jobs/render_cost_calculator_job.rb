class RenderCostCalculatorJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting Render cost calculator job..."

    calculator = RenderCostCalculator.new
    results = calculator.calculate_all_clients

    Rails.logger.info "Render cost calculator completed: #{results.inspect}"
    results
  end
end
