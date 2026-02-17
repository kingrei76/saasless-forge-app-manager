module EventRegistry
  Event = Data.define(:name, :category, :description, :data_schema)

  # Built-in framework events (always available)
  FRAMEWORK_EVENTS = [
    # Agent execution lifecycle events
    Event.new(
      name: "agent.execution.completed",
      category: "agent",
      description: "Fired when an agent execution completes successfully.",
      data_schema: [
        { path: "execution_id", type: "integer", description: "Execution ID" },
        { path: "agent_id", type: "integer", description: "Agent ID" },
        { path: "agent_slug", type: "string", description: "Agent slug" },
        { path: "status", type: "string", description: "Execution status" },
        { path: "total_tokens", type: "integer", description: "Total tokens used" },
        { path: "total_cost", type: "float", description: "Total cost in dollars" }
      ]
    ),
    Event.new(
      name: "agent.execution.failed",
      category: "agent",
      description: "Fired when an agent execution fails.",
      data_schema: [
        { path: "execution_id", type: "integer", description: "Execution ID" },
        { path: "agent_id", type: "integer", description: "Agent ID" },
        { path: "agent_slug", type: "string", description: "Agent slug" },
        { path: "error_message", type: "string", description: "Error message" }
      ]
    )
  ].freeze

  class << self
    # ---- Registration API (for apps to add custom events) ----

    # Register a single event
    #
    #   EventRegistry.register(
    #     name: "orders.placed",
    #     category: "commerce",
    #     description: "Fired when a new order is placed.",
    #     data_schema: [
    #       { path: "order_id", type: "integer", description: "Order ID" },
    #       { path: "total", type: "float", description: "Order total" }
    #     ]
    #   )
    def register(name:, category:, description:, data_schema: [])
      event = Event.new(name: name, category: category, description: description, data_schema: data_schema)
      custom_events.delete_if { |e| e.name == name } # Replace if already registered
      custom_events << event
      event
    end

    # Register a batch of events for a category
    #
    #   EventRegistry.register_category("stripe", [
    #     { name: "stripe.invoice.paid", description: "...", data_schema: [...] },
    #     ...
    #   ])
    def register_category(category, events)
      events.each do |event_def|
        register(
          name: event_def[:name],
          category: category,
          description: event_def[:description],
          data_schema: event_def[:data_schema] || []
        )
      end
    end

    # Auto-detect Stripe webhook events and register them.
    # Call this if your app uses Stripe — it registers all standard Stripe events
    # that the StripeWebhookService handles.
    def register_stripe_events!
      register_category("stripe", [
        {
          name: "stripe.invoice.paid",
          description: "Fired when a Stripe invoice is paid.",
          data_schema: [
            { path: "stripe_event_id", type: "string", description: "Stripe event ID" },
            { path: "type", type: "string", description: "Event type (invoice.paid)" },
            { path: "data.id", type: "string", description: "Stripe invoice ID" },
            { path: "data.amount_paid", type: "integer", description: "Amount paid in cents" },
            { path: "data.currency", type: "string", description: "Currency code (e.g. usd)" },
            { path: "data.customer", type: "string", description: "Stripe customer ID" },
            { path: "data.status", type: "string", description: "Invoice status" }
          ]
        },
        {
          name: "stripe.invoice.payment_failed",
          description: "Fired when a Stripe invoice payment fails.",
          data_schema: [
            { path: "stripe_event_id", type: "string", description: "Stripe event ID" },
            { path: "type", type: "string", description: "Event type (invoice.payment_failed)" },
            { path: "data.id", type: "string", description: "Stripe invoice ID" },
            { path: "data.attempt_count", type: "integer", description: "Number of payment attempts" },
            { path: "data.customer", type: "string", description: "Stripe customer ID" },
            { path: "data.amount_due", type: "integer", description: "Amount due in cents" }
          ]
        },
        {
          name: "stripe.invoice.overdue",
          description: "Fired when a Stripe invoice becomes overdue.",
          data_schema: [
            { path: "stripe_event_id", type: "string", description: "Stripe event ID" },
            { path: "type", type: "string", description: "Event type (invoice.overdue)" },
            { path: "data.id", type: "string", description: "Stripe invoice ID" },
            { path: "data.customer", type: "string", description: "Stripe customer ID" }
          ]
        },
        {
          name: "stripe.invoice.finalized",
          description: "Fired when a Stripe invoice is finalized.",
          data_schema: [
            { path: "stripe_event_id", type: "string", description: "Stripe event ID" },
            { path: "type", type: "string", description: "Event type (invoice.finalized)" },
            { path: "data.id", type: "string", description: "Stripe invoice ID" },
            { path: "data.status", type: "string", description: "Invoice status" },
            { path: "data.hosted_invoice_url", type: "string", description: "URL to hosted invoice page" },
            { path: "data.due_date", type: "integer", description: "Due date (Unix timestamp)" }
          ]
        },
        {
          name: "stripe.checkout.session.completed",
          description: "Fired when a Stripe Checkout session completes.",
          data_schema: [
            { path: "stripe_event_id", type: "string", description: "Stripe event ID" },
            { path: "type", type: "string", description: "Event type (checkout.session.completed)" },
            { path: "data.id", type: "string", description: "Checkout session ID" },
            { path: "data.mode", type: "string", description: "Session mode (payment, setup, subscription)" },
            { path: "data.customer", type: "string", description: "Stripe customer ID" },
            { path: "data.metadata", type: "object", description: "Session metadata" }
          ]
        }
      ])
    end

    # Clear all custom events (useful in tests)
    def reset!
      custom_events.clear
    end

    # ---- Query API ----

    def all_events
      FRAMEWORK_EVENTS + custom_events
    end

    def find_event(name)
      all_events.find { |e| e.name == name }
    end

    def field_schema_for(name)
      find_event(name)&.data_schema || []
    end

    def categories
      all_events.map(&:category).uniq.sort
    end

    def events_for_category(category)
      all_events.select { |e| e.category == category }
    end

    def event_names
      all_events.map(&:name)
    end

    private

    def custom_events
      @custom_events ||= []
    end
  end
end
