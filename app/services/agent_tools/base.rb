module AgentTools
  class Base
    def self.tool_metadata
      {
        name: tool_name,
        description: tool_description,
        category: tool_category,
        input_schema: tool_input_schema,
        output_schema: tool_output_schema,
        risk_level: tool_risk_level
      }
    end

    def self.tool_name
      name.demodulize.underscore.humanize
    end

    def self.tool_description
      "No description provided"
    end

    def self.tool_category
      "other"
    end

    def self.tool_input_schema
      {}
    end

    def self.tool_output_schema
      {}
    end

    def self.tool_risk_level
      "low"
    end

    def call(input_data)
      raise NotImplementedError, "Subclasses must implement #call"
    end
  end
end
