class BidWizardService
  STEPS = %w[describe clarify generate costs review].freeze

  def initialize(bid)
    @bid = bid
    @grok = GrokApiService.new(app: ai_app, trackable: bid)
  end

  def primary_app
    @bid.apps.first
  end

  def ai_app
    # Use an app that has an AI API key configured
    # First try the primary app for this bid, then fall back to any app with a key
    app = primary_app
    return app if app&.has_ai_api_key?

    App.where.not(ai_api_key: nil).first ||
      raise("No app with AI API key configured. Please configure an AI API key in an app's settings.")
  end

  def process_step(step, params)
    case step
    when "describe"
      process_describe(params)
    when "clarify"
      process_clarify(params)
    when "generate"
      process_generate(params)
    when "costs"
      process_costs(params)
    when "review"
      process_review(params)
    else
      { success: false, error: "Unknown step: #{step}" }
    end
  end

  def next_step(current_step)
    current_index = STEPS.index(current_step)
    return "complete" if current_index.nil? || current_index >= STEPS.length - 1
    STEPS[current_index + 1]
  end

  def previous_step(current_step)
    current_index = STEPS.index(current_step)
    return nil if current_index.nil? || current_index <= 0
    STEPS[current_index - 1]
  end

  def regenerate_questions
    return { success: false, error: "No project description" } if @bid.project_description.blank?

    repo_contexts = gather_repo_context
    questions = @grok.generate_clarifying_questions(
      @bid.project_description,
      repo_contexts: repo_contexts
    )
    @bid.wizard_questions = questions
    @bid.save!

    { success: true, questions: questions }
  rescue => e
    { success: false, error: e.message }
  end

  def regenerate_suggestions
    return { success: false, error: "No project description" } if @bid.project_description.blank?

    hourly_rate = @bid.hourly_rate || Setting[:default_hourly_rate]&.to_f || 60.0
    project_scope = @bid.project_scope || "small_feature"
    repo_contexts = gather_repo_context

    details = @grok.generate_bid_details(
      @bid.project_description,
      @bid.wizard_answers,
      hourly_rate: hourly_rate,
      project_scope: project_scope,
      repo_contexts: repo_contexts
    )

    @bid.suggested_items = details["suggested_items"]
    @bid.title = details["title"] if details["title"].present?
    @bid.requirements_summary = details["requirements_summary"] if details["requirements_summary"].present?
    @bid.save!

    { success: true, details: details }
  rescue => e
    { success: false, error: e.message }
  end

  def suggest_costs
    return { success: false, error: "No project description" } if @bid.project_description.blank?

    # Get client's existing infrastructure for context
    existing_infra = client_infrastructure_costs
    existing_descriptions = existing_infra.map { |c| c["description"] }

    # Gather repo context for gap analysis
    repo_contexts = gather_repo_context

    # Use AI to suggest costs, passing existing infrastructure and repo context
    ai_costs = @grok.suggest_system_costs(
      @bid.project_description,
      @bid.wizard_answers,
      existing_infrastructure: existing_descriptions,
      repo_contexts: repo_contexts
    )

    # Merge existing infrastructure with AI suggestions
    # Mark existing infra as not new, AI suggestions keep their is_new flag
    all_costs = []

    existing_infra.each do |cost|
      all_costs << cost.merge("is_new" => false, "from_infrastructure" => true)
    end

    # Better duplicate detection for AI suggestions
    ai_costs.each do |cost|
      ai_desc = cost["description"].to_s.downcase
      ai_category = cost["category"].to_s.downcase

      # Skip if this is a duplicate of existing infrastructure
      is_duplicate = existing_descriptions.any? do |existing_desc|
        existing_lower = existing_desc.to_s.downcase

        # Check for service type matches (Web Service, PostgreSQL, Redis, etc.)
        service_types = ["web service", "postgresql", "postgres", "redis", "database", "worker"]
        service_types.any? do |service_type|
          existing_lower.include?(service_type) && ai_desc.include?(service_type)
        end ||
        # Check for category overlap (hosting matches web service, database matches postgresql)
        (ai_category.include?("hosting") && existing_lower.include?("web service")) ||
        (ai_category.include?("database") && (existing_lower.include?("postgresql") || existing_lower.include?("postgres"))) ||
        # Check for storage - if they have a database, they have storage
        (ai_desc.include?("storage") && (existing_lower.include?("postgresql") || existing_lower.include?("postgres")))
      end

      next if is_duplicate

      all_costs << cost.merge("from_infrastructure" => false)
    end

    { success: true, costs: all_costs }
  rescue => e
    { success: false, error: e.message }
  end

  def client_infrastructure_costs
    return [] unless @bid.client.present?

    costs = []
    markup = @bid.client.effective_markup / 100.0

    # Get costs from selected bid_apps (existing apps only)
    selected_app_ids = @bid.bid_apps.where.not(app_id: nil).pluck(:app_id)

    if selected_app_ids.any?
      # Get render services for selected apps
      apps = App.where(id: selected_app_ids).includes(:render_services)
      apps.each do |app|
        app.render_services.active.each do |service|
          costs << {
            "description" => "#{app.name}: #{service.display_name}",
            "monthly_cost" => service.monthly_price,
            "customer_price" => (service.monthly_price * (1 + markup)).round(2),
            "category" => service.service_type_label,
            "from_infrastructure" => true
          }
        end
      end
    else
      # Fall back to all client apps if none selected
      @bid.client.apps.includes(:render_services).each do |app|
        app.render_services.active.each do |service|
          costs << {
            "description" => "#{app.name}: #{service.display_name}",
            "monthly_cost" => service.monthly_price,
            "customer_price" => (service.monthly_price * (1 + markup)).round(2),
            "category" => service.service_type_label,
            "from_infrastructure" => true
          }
        end
      end
    end

    costs
  end

  def gather_repo_context
    contexts = []

    # Get repo context for selected existing apps
    @bid.bid_apps.includes(app: :github_account).where.not(app_id: nil).each do |bid_app|
      app = bid_app.app
      next unless app.github_account&.access_token.present? && app.full_name.present?

      begin
        github = GithubApiService.new(access_token: app.github_account.access_token)
        structure = github.repo_structure_summary(repo: app.full_name)
        next unless structure

        contexts << {
          app_name: app.name,
          repo: app.full_name,
          languages: structure[:languages],
          total_files: structure[:total_files],
          directories: structure[:directories],
          key_files: structure[:key_files]
        }
      rescue => e
        Rails.logger.error("Failed to get repo context for #{app.name}: #{e.message}")
      end
    end

    contexts
  end

  private

  def process_app_selection(params)
    # Clear existing bid_apps and recreate based on selection
    @bid.bid_apps.destroy_all

    # Add selected existing apps
    if params[:app_ids].present?
      params[:app_ids].each do |app_id|
        next if app_id.blank?
        @bid.bid_apps.build(app_id: app_id)
      end
    end

    # Add new app names
    if params[:new_app_names].present?
      params[:new_app_names].each do |name|
        next if name.blank?
        @bid.bid_apps.build(new_app_name: name)
      end
    end
  end

  def process_describe(params)
    @bid.project_description = params[:project_description]
    @bid.client_id = params[:client_id] if params[:client_id].present?
    @bid.hourly_rate = params[:hourly_rate].presence || Setting[:default_hourly_rate]&.to_f || 60.0
    @bid.title = params[:title].presence || "New Project Bid"
    @bid.project_scope = params[:project_scope].presence || "small_feature"

    # Handle app selection
    process_app_selection(params)

    # Generate clarifying questions from Grok
    if @bid.project_description.present?
      # Generate title suggestion if still default
      if @bid.title == "New Project Bid"
        suggested_title = @grok.suggest_title(@bid.project_description)
        @bid.title = suggested_title if suggested_title.present?
      end

      # Save bid first to persist bid_apps, then gather repo context
      @bid.save!
      repo_contexts = gather_repo_context

      questions = @grok.generate_clarifying_questions(
        @bid.project_description,
        repo_contexts: repo_contexts
      )
      @bid.wizard_questions = questions
    end

    @bid.current_wizard_step = "clarify"
    @bid.save!

    { success: true, next_step: "clarify" }
  rescue => e
    { success: false, error: e.message }
  end

  def process_clarify(params)
    # Store answers
    answers = {}
    @bid.wizard_questions.each_with_index do |q, i|
      answer_key = "question_#{i}"
      answers[q["question"]] = params[answer_key] if params[answer_key].present?
    end
    @bid.wizard_answers = answers

    # Gather repo context from selected apps
    repo_contexts = gather_repo_context

    # Generate bid details from Grok
    hourly_rate = @bid.hourly_rate || 60.0
    project_scope = @bid.project_scope || "small_feature"
    details = @grok.generate_bid_details(
      @bid.project_description,
      answers,
      hourly_rate: hourly_rate,
      project_scope: project_scope,
      repo_contexts: repo_contexts
    )

    @bid.title = details["title"] if details["title"].present?
    @bid.requirements_summary = details["requirements_summary"]
    @bid.suggested_items = details["suggested_items"]
    @bid.features_list = details["features_list"] if details["features_list"].present?

    @bid.current_wizard_step = "generate"
    @bid.save!

    { success: true, next_step: "generate" }
  rescue => e
    { success: false, error: e.message }
  end

  def process_generate(params)
    # Clear existing development line items
    @bid.line_items.development.destroy_all

    # Create line items from submitted items
    # params[:items] comes as a hash like {"0" => {...}, "1" => {...}}
    items = params[:items].present? ? params[:items].values : []
    items.each_with_index do |item, index|
      next if item["description"].blank?

      @bid.line_items.create!(
        description: item["description"],
        hours: item["hours"].to_f,
        rate: @bid.hourly_rate || 150.0,
        position: index + 1,
        line_item_type: "development",
        work_category: map_ai_category_to_enum(item["category"])
      )
    end

    @bid.current_wizard_step = "costs"
    @bid.save!

    { success: true, next_step: "costs" }
  rescue => e
    { success: false, error: e.message }
  end

  def map_ai_category_to_enum(ai_category)
    return nil if ai_category.blank?

    mapping = {
      "Discovery & Setup" => "discovery_planning",
      "Discovery & Planning" => "discovery_planning",
      "Planning" => "discovery_planning",
      "Setup" => "discovery_planning",
      "Core Development" => "development",
      "Development" => "development",
      "Integration" => "integration",
      "Integration & Testing" => "integration",
      "Testing" => "testing_qa",
      "Testing & QA" => "testing_qa",
      "QA" => "testing_qa",
      "Polish & Deployment" => "deployment_devops",
      "Deployment" => "deployment_devops",
      "DevOps" => "deployment_devops"
    }
    mapping[ai_category] || "development"
  end

  def process_costs(params)
    # Clear existing system cost line items
    @bid.line_items.system_costs.destroy_all

    # Create system cost line items
    # params[:costs] comes as a hash like {"0" => {...}, "1" => {...}}
    items = params[:costs].present? ? params[:costs].values : []
    items.each_with_index do |item, index|
      next if item["description"].blank?

      @bid.line_items.create!(
        description: item["description"],
        unit_cost: item["unit_cost"].to_f,
        is_recurring: item["is_recurring"] == "1" || item["is_recurring"] == true,
        billing_frequency: item["billing_frequency"].presence || "monthly",
        position: index + 1,
        line_item_type: "system_cost",
        is_new_system: item["is_new_system"] == "1" || item["is_new_system"] == "true" || item["is_new_system"] == true,
        system_category: item["system_category"]
      )
    end

    @bid.current_wizard_step = "review"
    @bid.save!

    { success: true, next_step: "review" }
  rescue => e
    { success: false, error: e.message }
  end

  def process_review(params)
    # Final updates before saving
    @bid.title = params[:title] if params[:title].present?
    @bid.requirements_summary = params[:requirements_summary] if params[:requirements_summary].present?
    @bid.notes = params[:notes] if params[:notes].present?

    @bid.ai_generated = true
    @bid.current_wizard_step = "complete"
    @bid.recalculate_total!

    { success: true, next_step: "complete", bid: @bid }
  rescue => e
    { success: false, error: e.message }
  end
end
