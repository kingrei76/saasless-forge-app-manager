class RenderSyncService
  PLAN_PRICES = {
    "free" => 0,
    "starter" => 7,
    "standard" => 25,
    "pro" => 85,
    "pro_plus" => 175,
    "pro_max" => 225,
    "pro_ultra" => 450
  }.freeze

  DATABASE_PLAN_PRICES = {
    "free" => 0,
    "basic_256mb" => 6,
    "basic_1gb" => 19,
    "basic_4gb" => 75,
    "pro_4gb" => 55,
    "pro_8gb" => 100,
    "pro_16gb" => 200,
    "pro_32gb" => 400
  }.freeze

  IGNORED_SERVICE_TYPES = %w[static_site].freeze

  # Initialize with either a github_account or an explicit api_key
  # github_account takes precedence for the new per-account architecture
  def initialize(github_account: nil, api_key: nil)
    @github_account = github_account
    effective_api_key = github_account&.render_api_key || api_key
    @api = RenderApiService.new(api_key: effective_api_key)
  end

  def sync
    apps_by_name = App.all.index_by { |a| a.name.downcase }
    period_start = Date.today.beginning_of_month
    period_end = Date.today.end_of_month

    results = { created: 0, updated: 0, matched: 0, unmatched: [], services_synced: 0 }

    # Sync to RenderService model first
    sync_render_services(results)

    # Then sync cost entries (legacy behavior)
    sync_services(apps_by_name, period_start, period_end, results)
    sync_postgres(apps_by_name, period_start, period_end, results)

    results
  end

  # Sync all Render services to RenderService model
  def sync_render_services(results = { services_synced: 0, services_created: 0, services_updated: 0 })
    sync_web_services_to_model(results)
    sync_postgres_to_model(results)
    sync_workspaces(results)

    results
  end

  # Sync app metadata (render_service_id, type, plan, etc.) without creating cost entries
  def sync_app_metadata
    apps_scope = @github_account ? @github_account.apps : App.all
    apps_by_name = apps_scope.index_by { |a| a.name.downcase }
    results = { updated: 0, matched: 0, unmatched: [], services_synced: 0 }

    # Sync to RenderService model
    sync_render_services(results)

    # Legacy: also update App records
    sync_service_metadata(apps_by_name, results)
    sync_postgres_metadata(apps_by_name, results)

    results
  end

  # Sync workspace/owner information
  def sync_workspaces(results = { workspaces_synced: 0 })
    owners = @api.list_owners

    owners.each do |owner_data|
      owner = owner_data["owner"]
      next unless owner

      workspace = RenderWorkspace.find_or_initialize_by(render_owner_id: owner["id"])
      workspace.assign_attributes(
        name: owner["name"],
        email: owner["email"],
        workspace_type: owner["type"],
        raw_data: owner
      )
      workspace.save!
      results[:workspaces_synced] = (results[:workspaces_synced] || 0) + 1
    end

    results
  rescue => e
    Rails.logger.error "Failed to sync workspaces: #{e.message}"
    results
  end

  private

  def sync_web_services_to_model(results)
    services = @api.list_services

    # If syncing for a specific github_account, only match apps belonging to that account
    apps_scope = @github_account ? @github_account.apps : App.all
    apps_by_name = apps_scope.index_by { |a| a.name.downcase }

    services.each do |svc|
      next if IGNORED_SERVICE_TYPES.include?(svc["type"])

      plan = extract_plan(svc, svc["type"])
      Rails.logger.info "[RenderSync] Service '#{svc['name']}' (#{svc['type']}): plan=#{plan}, raw_plan_data=#{svc['servicePlan'].inspect}"

      created_at = svc["createdAt"] ? Time.parse(svc["createdAt"]) : nil

      render_service = RenderService.find_or_initialize_by(render_service_id: svc["id"])
      is_new = render_service.new_record?

      render_service.assign_attributes(
        name: svc["name"],
        service_type: svc["type"],
        plan: plan,
        render_owner_id: svc["ownerId"],
        render_created_at: created_at,
        suspended: svc["suspended"] == "suspended",
        raw_data: svc
      )

      # Auto-link to app if not already linked and name matches
      if render_service.app_id.nil?
        matching_app = apps_by_name[svc["name"].to_s.downcase]
        render_service.app = matching_app if matching_app
      end

      render_service.save!

      if is_new
        results[:services_created] = (results[:services_created] || 0) + 1
      else
        results[:services_updated] = (results[:services_updated] || 0) + 1
      end
      results[:services_synced] = (results[:services_synced] || 0) + 1
    end
  end

  def sync_postgres_to_model(results)
    databases = @api.list_postgres

    # If syncing for a specific github_account, only match apps belonging to that account
    apps_scope = @github_account ? @github_account.apps : App.all
    apps_by_name = apps_scope.index_by { |a| a.name.downcase }

    databases.each do |db|
      plan = db["plan"] || "free"
      Rails.logger.info "[RenderSync] PostgreSQL '#{db['name']}': plan=#{plan}"

      created_at = db["createdAt"] ? Time.parse(db["createdAt"]) : nil

      render_service = RenderService.find_or_initialize_by(render_service_id: db["id"])
      is_new = render_service.new_record?

      render_service.assign_attributes(
        name: db["name"],
        service_type: "postgres",
        plan: plan,
        render_owner_id: db["ownerId"],
        render_created_at: created_at,
        suspended: db["suspended"] == "suspended",
        raw_data: db
      )

      # Auto-link to app if not already linked
      if render_service.app_id.nil?
        matching_app = match_database_to_app(db, apps_by_name)
        render_service.app = matching_app if matching_app
      end

      render_service.save!

      if is_new
        results[:services_created] = (results[:services_created] || 0) + 1
      else
        results[:services_updated] = (results[:services_updated] || 0) + 1
      end
      results[:services_synced] = (results[:services_synced] || 0) + 1
    end
  end

  # Extract plan from service data with improved detection
  def extract_plan(svc, service_type)
    # Try multiple paths for plan data
    plan = svc.dig("servicePlan", "plan") ||
           svc.dig("serviceDetails", "plan") ||
           svc.dig("plan") ||
           svc.dig("servicePlan", "name")

    # Log all available plan-related fields for debugging
    if plan.nil? || plan == "free"
      Rails.logger.debug "[RenderSync] Plan detection for '#{svc['name']}': " \
        "servicePlan=#{svc['servicePlan'].inspect}, " \
        "serviceDetails=#{svc['serviceDetails'].inspect}, " \
        "plan=#{svc['plan'].inspect}"
    end

    plan || "free"
  end

  def sync_service_metadata(apps_by_name, results)
    services = @api.list_services

    services.each do |svc|
      next if svc["suspended"] == "suspended"
      next if IGNORED_SERVICE_TYPES.include?(svc["type"])

      app = apps_by_name[svc["name"].to_s.downcase]
      unless app
        results[:unmatched] << svc["name"]
        next
      end

      results[:matched] += 1

      plan = svc.dig("servicePlan", "plan") || svc.dig("plan") || "free"
      created_at = svc["createdAt"] ? Time.parse(svc["createdAt"]) : nil

      app.update!(
        render_service_id: svc["id"],
        render_service_type: svc["type"],
        render_plan: plan,
        render_owner_id: svc["ownerId"],
        render_created_at: created_at
      )

      results[:updated] += 1
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn "[RenderSync] Skipped metadata for '#{svc['name']}': #{e.message}"
    end
  end

  def sync_postgres_metadata(apps_by_name, results)
    databases = @api.list_postgres

    databases.each do |db|
      next if db["suspended"] == "suspended"

      app = match_database_to_app(db, apps_by_name)
      unless app
        results[:unmatched] << "#{db['name']} (PostgreSQL)"
        next
      end

      results[:matched] += 1

      # For databases, we might want to track them separately
      # For now, if an app already has a render_service_id from a web service,
      # we don't overwrite it
      next if app.render_service_id.present?

      created_at = db["createdAt"] ? Time.parse(db["createdAt"]) : nil

      app.update!(
        render_service_id: db["id"],
        render_service_type: "postgres",
        render_plan: db["plan"] || "free",
        render_owner_id: db["ownerId"],
        render_created_at: created_at
      )

      results[:updated] += 1
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn "[RenderSync] Skipped postgres metadata for '#{db['name']}': #{e.message}"
    end
  end

  def sync_services(apps_by_name, period_start, period_end, results)
    services = @api.list_services

    services.each do |svc|
      next if svc["suspended"] == "suspended"
      next if IGNORED_SERVICE_TYPES.include?(svc["type"])

      plan = svc.dig("servicePlan", "plan") || svc.dig("plan") || "free"
      num_instances = svc.dig("servicePlan", "numInstances") || 1
      monthly_cost = (PLAN_PRICES[plan] || 0) * num_instances

      app = apps_by_name[svc["name"].to_s.downcase]

      unless app
        results[:unmatched] << svc["name"]
        next
      end

      results[:matched] += 1

      entry = CostEntry.find_or_initialize_by(
        source_type: "render",
        source_id: svc["id"],
        period_start: period_start
      )

      is_new = entry.new_record?

      entry.assign_attributes(
        app: app,
        service_name: "Render – #{svc['name']} (#{svc['type']})",
        amount: monthly_cost,
        currency: "USD",
        period_end: period_end,
        notes: "Auto-synced from Render. Plan: #{plan}, instances: #{num_instances}"
      )

      entry.save!
      is_new ? results[:created] += 1 : results[:updated] += 1
    end
  end

  def sync_postgres(apps_by_name, period_start, period_end, results)
    databases = @api.list_postgres

    databases.each do |db|
      next if db["suspended"] == "suspended"

      plan = db["plan"] || "free"
      monthly_cost = DATABASE_PLAN_PRICES[plan] || 0

      app = match_database_to_app(db, apps_by_name)

      unless app
        results[:unmatched] << "#{db['name']} (PostgreSQL)"
        next
      end

      results[:matched] += 1

      entry = CostEntry.find_or_initialize_by(
        source_type: "render",
        source_id: db["id"],
        period_start: period_start
      )

      is_new = entry.new_record?

      entry.assign_attributes(
        app: app,
        service_name: "Render – PostgreSQL (#{plan})",
        amount: monthly_cost,
        currency: "USD",
        period_end: period_end,
        notes: "Auto-synced from Render. Database: #{db['name']}, plan: #{plan}"
      )

      entry.save!
      is_new ? results[:created] += 1 : results[:updated] += 1
    end
  end

  def match_database_to_app(db, apps_by_name)
    db_name = db["name"].to_s.downcase

    # Exact match
    return apps_by_name[db_name] if apps_by_name[db_name]

    # Fuzzy match: check if any app name starts with or contains the database name
    apps_by_name.each do |app_name, app|
      return app if app_name.include?(db_name) || db_name.include?(app_name)
    end

    nil
  end
end
