# frozen_string_literal: true

module AgentTools
  module Database
    class SearchRecords < AgentTools::Base
      def self.tool_name = "Search Records"
      def self.tool_description = "Search records in allow-listed models by column values. Supports text search and basic filtering on any visible column."
      def self.tool_category = "database"
      def self.tool_risk_level = "low"

      ALLOWED_MODELS = {
        "Client" => Client,
        "Project" => Project,
        "Invoice" => Invoice,
        "App" => App,
        "User" => User,
        "CostEntry" => CostEntry,
        "TimeEntry" => TimeEntry,
        "Bid" => Bid,
        "Agent" => Agent,
        "ToolDefinition" => ToolDefinition
      }.freeze

      def self.tool_input_schema
        {
          type: "object",
          properties: {
            model: { type: "string", enum: ALLOWED_MODELS.keys, description: "Model to search" },
            query: { type: "string", description: "Text to search for (searches name/title/description columns)" },
            filters: {
              type: "object",
              description: "Column-value pairs to filter by (e.g. {\"status\": \"active\"})"
            },
            limit: { type: "integer", description: "Max results (default 20)" }
          },
          required: ["model"]
        }
      end

      def call(input_data)
        model_class = ALLOWED_MODELS[input_data["model"]]
        return { error: "Model '#{input_data["model"]}' is not allowed. Allowed: #{ALLOWED_MODELS.keys.join(", ")}" } unless model_class

        scope = model_class.all

        # Text search across common text columns
        if input_data["query"].present?
          text_columns = model_class.column_names.select { |c| c.match?(/name|title|description|email|slug/) }
          if text_columns.any?
            conditions = text_columns.map { |c| "#{model_class.table_name}.#{c} ILIKE :q" }.join(" OR ")
            scope = scope.where(conditions, q: "%#{input_data["query"]}%")
          end
        end

        # Apply exact-match filters
        if input_data["filters"].is_a?(Hash)
          input_data["filters"].each do |column, value|
            if model_class.column_names.include?(column)
              scope = scope.where(column => value)
            end
          end
        end

        limit = (input_data["limit"] || 20).to_i.clamp(1, 100)
        records = scope.limit(limit)

        # Return a compact representation
        columns = model_class.column_names - %w[encrypted_password reset_password_token]
        serializable_columns = columns.first(15) # Cap columns for readability

        {
          model: input_data["model"],
          records: records.map { |r|
            serializable_columns.each_with_object({}) { |c, h| h[c] = r.send(c) }
          },
          total_count: scope.count,
          columns_shown: serializable_columns
        }
      rescue => e
        { error: e.message }
      end
    end
  end
end
