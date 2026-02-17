class Api::TriggerSchemasController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_user!

  def show
    fields = case params[:context]
             when "event"
               event_fields(params[:event_name])
             when "data"
               data_fields(params[:tool_definition_id])
             when "webhook"
               webhook_fields
             when "dependency"
               dependency_fields
             else
               []
             end

    render json: { fields: fields }
  end

  private

  def event_fields(event_name)
    return [] if event_name.blank?

    schema = EventRegistry.field_schema_for(event_name)
    schema.map do |f|
      { path: f[:path], type: f[:type], description: f[:description] }
    end
  end

  def data_fields(tool_definition_id)
    return [] if tool_definition_id.blank?

    tool = ToolDefinition.find_by(id: tool_definition_id)
    return [] unless tool

    schema = tool.try(:output_schema)
    return [] if schema.blank?

    flatten_json_schema(schema)
  end

  def webhook_fields
    [
      { path: "body", type: "object", description: "Full JSON body of the webhook POST" },
      { path: "headers.content-type", type: "string", description: "Content-Type header" },
      { path: "headers.x-webhook-id", type: "string", description: "Webhook ID header (if sent)" }
    ]
  end

  def dependency_fields
    [
      { path: "status", type: "string", description: "Execution status (completed)" },
      { path: "output_data", type: "object", description: "Output data from the execution" },
      { path: "total_tokens", type: "integer", description: "Total tokens used" },
      { path: "total_cost", type: "float", description: "Total cost in dollars" }
    ]
  end

  # Flatten a JSON Schema into dot-path fields
  def flatten_json_schema(schema, prefix = "")
    fields = []
    return fields unless schema.is_a?(Hash)

    properties = schema["properties"] || schema[:properties] || {}
    properties.each do |key, value|
      path = prefix.present? ? "#{prefix}.#{key}" : key.to_s
      type = value["type"] || value[:type] || "string"
      desc = value["description"] || value[:description] || ""

      fields << { path: path, type: type, description: desc }

      if type == "object" && (value["properties"] || value[:properties])
        fields.concat(flatten_json_schema(value, path))
      end
    end

    fields
  end
end
