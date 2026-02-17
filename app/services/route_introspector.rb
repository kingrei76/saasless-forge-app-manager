module RouteIntrospector
  class << self
    # Returns all application routes categorized and structured
    def discover
      {
        api_endpoints: api_endpoints,
        admin_endpoints: admin_endpoints,
        webhook_endpoints: webhook_endpoints,
        auth_endpoints: auth_endpoints,
        summary: summary
      }
    end

    # All API routes (namespace :api)
    def api_endpoints
      routes_matching(%r{^/api/}).map { |r| format_route(r) }
    end

    # All admin routes (namespace :admin)
    def admin_endpoints
      routes_matching(%r{^/admin/}).map { |r| format_route(r) }
    end

    # Routes that receive external webhooks (POST endpoints without auth)
    def webhook_endpoints
      all_routes.select { |r|
        path = route_path(r)
        verb = route_verb(r)
        verb == "POST" && (
          path.include?("webhook") ||
          path.include?("callback") ||
          path.match?(%r{/triggers/})
        )
      }.map { |r| format_route(r).merge(webhook: true) }
    end

    # Auth-related routes (Devise, OAuth, etc.)
    def auth_endpoints
      all_routes.select { |r|
        path = route_path(r)
        path.match?(%r{/(sign_in|sign_out|sign_up|password|auth|session|registration)})
      }.map { |r| format_route(r) }
    end

    # Routes suitable for agent interaction (API + webhooks, excluding static/assets)
    def actionable_routes
      all_routes.select { |r|
        path = route_path(r)
        verb = route_verb(r)
        # Only include routes that agents could use
        path.start_with?("/api/") &&
          !path.include?("agent_callbacks") && # Internal service-to-service
          verb.present?
      }.map { |r| format_route(r) }
    end

    # High-level summary of routes
    def summary
      routes = all_routes
      {
        total_routes: routes.size,
        api_routes: routes.count { |r| route_path(r).start_with?("/api/") },
        admin_routes: routes.count { |r| route_path(r).start_with?("/admin/") },
        webhook_routes: webhook_endpoints.size,
        namespaces: extract_namespaces(routes),
        http_methods: routes.group_by { |r| route_verb(r) }.transform_values(&:size)
      }
    end

    private

    def all_routes
      @all_routes ||= Rails.application.routes.routes.reject { |r|
        # Skip internal Rails routes (assets, health checks, PWA, etc.)
        path = route_path(r)
        path.blank? ||
          (r.respond_to?(:internal?) && r.internal?) ||
          path.start_with?("/rails/") ||
          path.start_with?("/assets") ||
          path == "/up" ||
          path == "/service-worker" ||
          path == "/manifest"
      }
    end

    def routes_matching(pattern)
      all_routes.select { |r| route_path(r).match?(pattern) }
    end

    def route_path(route)
      route.path.spec.to_s.gsub("(.:format)", "").gsub(/\(\.:format\)/, "")
    end

    def route_verb(route)
      route.verb.to_s.presence || route.constraints[:request_method]&.to_s&.gsub(/[^A-Z|]/, "") || ""
    end

    def format_route(route)
      path = route_path(route)
      controller, action = route.defaults.values_at(:controller, :action)
      {
        method: route_verb(route),
        path: path,
        controller: controller,
        action: action,
        name: route.name,
        params: extract_params(path)
      }.compact
    end

    def extract_params(path)
      path.scan(/:(\w+)/).flatten
    end

    def extract_namespaces(routes)
      routes.map { |r|
        parts = route_path(r).split("/").reject(&:blank?)
        parts.first if parts.size > 1
      }.compact.uniq.sort
    end

    # Reset memoization (useful in development)
    def reset!
      @all_routes = nil
    end
  end
end
