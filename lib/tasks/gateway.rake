namespace :gateway do
  desc "Migrate model entries from service_provider pricing_rules into ai_models table"
  task migrate_models: :environment do
    ServiceProvider.where(category: "llm").find_each do |provider|
      models = provider.pricing_rules.dig("models")
      next unless models.is_a?(Hash)

      models.each do |model_id, pricing|
        ai_model = AiModel.find_or_initialize_by(
          service_provider: provider,
          model_id: model_id
        )

        ai_model.name ||= model_id.titleize.gsub("-", " ")
        ai_model.category = "chat"
        ai_model.input_price_per_million = pricing["input"].to_f if pricing["input"]
        ai_model.output_price_per_million = pricing["output"].to_f if pricing["output"]
        ai_model.status = "active"

        if ai_model.save
          puts "  #{ai_model.new_record? ? 'Created' : 'Updated'}: #{provider.name} / #{model_id}"
        else
          puts "  FAILED: #{provider.name} / #{model_id}: #{ai_model.errors.full_messages.join(', ')}"
        end
      end
    end

    puts "\nDone. Total AI models: #{AiModel.count}"
  end
end
