module ModelIntrospector
  class << self
    # Returns all application models with columns, associations, and validations
    def discover
      models = app_models.map { |klass| introspect_model(klass) }
      {
        models: models,
        summary: {
          total_models: models.size,
          total_tables: models.count { |m| m[:table_exists] },
          categories: categorize_models(models)
        }
      }
    end

    # Quick list of model names and their relationships
    def model_map
      app_models.map { |klass|
        {
          name: klass.name,
          table: safe_table_name(klass),
          associations: safe_associations(klass).map { |a|
            { name: a.name.to_s, type: a.macro.to_s, target: a.class_name }
          }
        }
      }
    end

    # Detailed introspection of a single model by name
    def introspect(model_name)
      klass = model_name.safe_constantize
      return nil unless klass && klass < ActiveRecord::Base
      introspect_model(klass)
    end

    private

    def app_models
      # Eager-load all models so we can discover them
      Rails.application.eager_load! unless Rails.application.config.eager_load

      ActiveRecord::Base.descendants.select { |klass|
        # Only include app models (not framework internals)
        klass.name.present? &&
          !klass.abstract_class? &&
          !klass.name.start_with?("ActiveRecord::") &&
          !klass.name.start_with?("ActionText::") &&
          !klass.name.start_with?("ActionMailbox::") &&
          !klass.name.start_with?("ActiveStorage::") &&
          !klass.name.start_with?("SolidQueue::") &&
          !klass.name.start_with?("SolidCache::") &&
          defined_in_app?(klass)
      }.sort_by(&:name)
    rescue => e
      Rails.logger.warn("ModelIntrospector: Failed to load models: #{e.message}")
      []
    end

    def defined_in_app?(klass)
      source = klass.instance_method(:initialize).source_location&.first rescue nil
      source ||= begin
        klass.instance_methods(false).first.then { |m|
          klass.instance_method(m).source_location&.first if m
        }
      rescue
        nil
      end

      # If we can't determine source, check if the model file exists in app/models
      return File.exist?(Rails.root.join("app/models/#{klass.name.underscore}.rb")) if source.nil?
      source.include?(Rails.root.to_s)
    end

    def introspect_model(klass)
      table = safe_table_name(klass)
      table_exists = table.present? && ActiveRecord::Base.connection.table_exists?(table) rescue false

      result = {
        name: klass.name,
        table_name: table,
        table_exists: table_exists
      }

      if table_exists
        result[:columns] = safe_columns(klass)
        result[:associations] = safe_associations(klass).map { |a| format_association(a) }
        result[:validations] = safe_validations(klass)
        result[:scopes] = safe_scopes(klass)
        result[:enums] = safe_enums(klass)
        result[:constants] = safe_constants(klass)
      end

      result
    end

    def safe_table_name(klass)
      klass.table_name
    rescue
      nil
    end

    def safe_columns(klass)
      klass.columns.map { |col|
        {
          name: col.name,
          type: col.type.to_s,
          null: col.null,
          default: col.default
        }
      }
    rescue
      []
    end

    def safe_associations(klass)
      klass.reflect_on_all_associations
    rescue
      []
    end

    def format_association(assoc)
      result = {
        name: assoc.name.to_s,
        type: assoc.macro.to_s, # belongs_to, has_many, has_one, etc.
        target_model: assoc.class_name
      }
      result[:foreign_key] = assoc.foreign_key.to_s if assoc.respond_to?(:foreign_key)
      result[:through] = assoc.options[:through].to_s if assoc.options[:through]
      result[:optional] = assoc.options[:optional] if assoc.options.key?(:optional)
      result[:dependent] = assoc.options[:dependent].to_s if assoc.options[:dependent]
      result
    end

    def safe_validations(klass)
      klass.validators.map { |v|
        {
          type: v.class.name.demodulize.underscore.sub(/_validator$/, ""),
          attributes: v.attributes.map(&:to_s),
          options: v.options.except(:if, :unless, :on).transform_values(&:to_s)
        }
      }
    rescue
      []
    end

    def safe_scopes(klass)
      # Scopes are stored as class methods that return ActiveRecord::Relation
      # We can detect them by checking for scope definitions
      scopes = []
      klass.defined_enums.each_key { |e| scopes << e.to_s }

      # Check for explicitly defined scopes
      if klass.respond_to?(:scope_names)
        scopes += klass.scope_names.map(&:to_s)
      else
        # Heuristic: look for class methods that aren't standard AR methods
        klass.methods(false).each do |method_name|
          next if method_name.to_s.start_with?("_")
          begin
            # Check if it's a scope by looking at the source location
            loc = klass.method(method_name).source_location
            if loc && loc.first.include?("app/models")
              scopes << method_name.to_s
            end
          rescue
            next
          end
        end
      end

      scopes.uniq.sort
    rescue
      []
    end

    def safe_enums(klass)
      return {} unless klass.respond_to?(:defined_enums)
      klass.defined_enums.transform_values { |v| v.keys }
    rescue
      {}
    end

    def safe_constants(klass)
      # Look for UPPERCASE constants that are arrays or hashes (enum-like)
      result = {}
      klass.constants(false).each do |const_name|
        next unless const_name.to_s == const_name.to_s.upcase
        value = klass.const_get(const_name)
        case value
        when Array
          result[const_name.to_s] = value if value.all? { |v| v.is_a?(String) || v.is_a?(Symbol) }
        when Hash
          result[const_name.to_s] = value.keys.map(&:to_s) if value.values.all? { |v| v.is_a?(String) }
        end
      rescue
        next
      end
      result
    end

    def categorize_models(models)
      categories = Hash.new { |h, k| h[k] = [] }
      models.each do |m|
        name = m[:name]
        category = if name.start_with?("Agent")
                     "agents"
                   elsif name.start_with?("Tool")
                     "tools"
                   elsif %w[Invoice RecurringInvoice LineItem BillingRate].include?(name)
                     "billing"
                   elsif %w[User AllowedEmail].include?(name)
                     "auth"
                   elsif %w[App Client AppAssignment].include?(name)
                     "core"
                   else
                     "other"
                   end
        categories[category] << name
      end
      categories
    end
  end
end
