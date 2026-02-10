require "net/http"
require "json"

class GrokApiService
  BASE_URL = "https://api.x.ai/v1"

  attr_accessor :trackable, :current_operation, :app

  def initialize(app:, trackable: nil)
    @app = app
    @api_key = app.ai_api_key
    @trackable = trackable
    @current_operation = nil

    raise "No AI API key configured for #{app.name}" unless @api_key.present?
  end

  def test_connection
    response = chat([{ role: "user", content: "Say 'Connection successful!' in exactly those words." }], operation: "test_connection")
    { success: true, message: response }
  rescue => e
    { success: false, error: e.message }
  end

  def chat(messages, model: "grok-3", operation: nil)
    uri = URI("#{BASE_URL}/chat/completions")

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{@api_key}"

    request.body = {
      model: model,
      messages: messages,
      temperature: 0.7
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 60, open_timeout: 10) do |http|
      http.request(request)
    end

    if response.code.to_i == 200
      data = JSON.parse(response.body)
      log_usage(data, model, operation || @current_operation)
      data.dig("choices", 0, "message", "content")
    else
      error_body = JSON.parse(response.body) rescue { "error" => response.body }
      raise "Grok API error (#{response.code}): #{error_body['error']}"
    end
  end

  def generate_clarifying_questions(project_description, repo_contexts: [])
    repo_context_text = if repo_contexts.present?
      repo_contexts.map do |ctx|
        <<~REPO
          App: #{ctx[:app_name]} (#{ctx[:repo]})
          Languages: #{ctx[:languages]&.keys&.join(", ") || "Unknown"}
          Directories: #{ctx[:directories]&.first(10)&.join(", ")}
          Key files: #{ctx[:key_files]&.join(", ")}
        REPO
      end.join("\n")
    else
      ""
    end

    repo_context_instruction = if repo_context_text.present?
      <<~INSTRUCTION

        EXISTING CODEBASE ANALYSIS:
        #{repo_context_text}

        IMPORTANT: The codebase above already exists. Analyze what's already implemented vs what's needed for this project.
      INSTRUCTION
    else
      ""
    end

    system_prompt = <<~PROMPT
      You are an expert software development consultant at a services company that builds applications for clients.

      CONTEXT: We are preparing a proposal/bid for a CLIENT'S project. The questions you generate will be answered by someone at OUR company who is gathering information about the CLIENT'S needs.

      #{repo_context_instruction}

      Your goal is to ask questions that help us create a customer-facing proposal containing:
      1. A clear summary of the CLIENT'S problem and our proposed solution
      2. A list of features/capabilities the CLIENT will receive
      3. Accurate estimates for infrastructure/system costs the CLIENT will pay

      FOCUS QUESTIONS ON THE CLIENT'S BUSINESS:
      - What problem is the CLIENT trying to solve for THEIR customers/users?
      - How will the CLIENT'S end-users interact with this feature/application?
      - What is the CLIENT'S expected usage volume? (for infrastructure cost estimates)
        * If AI/LLM involved: how many AI interactions per month?
        * If web app: how many users does the CLIENT expect?
        * If data processing: what volume of data?
      - What third-party services will the CLIENT need? (payments, email, AI providers, etc.)

      DO NOT ASK ABOUT:
      - Technical implementation details (we handle those internally)
      - Our internal development process
      - Framework or language preferences
      - Timeline or scheduling

      Generate 3-5 questions maximum. Each question should help us understand the CLIENT'S needs.

      Respond with a JSON array of question objects:
      - "question": The question text (phrased to ask about the CLIENT)
      - "type": One of "text", "select", or "multiselect"
      - "options": (optional) Array of options for select/multiselect types

      Example for an AI chatbot project for a client:
      [
        {"question": "What problem will this AI assistant solve for the client's customers?", "type": "text"},
        {"question": "How many AI conversations does the client expect per month?", "type": "select", "options": ["Under 1,000", "1,000 - 10,000", "10,000 - 100,000", "Over 100,000"]},
        {"question": "What data sources should the AI have access to?", "type": "multiselect", "options": ["Client's knowledge base", "Product catalog", "Customer history", "Website content", "Other"]},
        {"question": "What actions should the client's users be able to take through the AI?", "type": "multiselect", "options": ["Get answers to questions", "Make purchases", "Schedule appointments", "Submit support tickets", "Other"]}
      ]

      Only respond with valid JSON, no other text.
    PROMPT

    messages = [
      { role: "system", content: system_prompt },
      { role: "user", content: "Project description:\n\n#{project_description}" }
    ]

    response = chat(messages, operation: "generate_clarifying_questions")
    parse_json_response(response, default: [])
  end

  def generate_bid_details(project_description, answers, hourly_rate: 150, project_scope: "small_feature", repo_contexts: [])
    scope_context = scope_hour_ranges(project_scope)

    repo_context_text = if repo_contexts.present?
      repo_contexts.map do |ctx|
        <<~REPO
          App: #{ctx[:app_name]} (#{ctx[:repo]})
          Languages: #{ctx[:languages]&.keys&.join(", ") || "Unknown"}
          Total files: #{ctx[:total_files]}
          Directories: #{ctx[:directories]&.first(10)&.join(", ")}
          Key files: #{ctx[:key_files]&.join(", ")}
        REPO
      end.join("\n")
    else
      ""
    end

    system_prompt = <<~PROMPT
      You are an expert software development estimator for a team that uses AI-assisted development (Claude Code, Cursor, GitHub Copilot).

      CRITICAL CONTEXT - AI-ASSISTED DEVELOPMENT:
      This team uses Claude Code and similar AI tools for 80-90% of coding tasks. This dramatically reduces development time:
      - Boilerplate code: AI generates in seconds what would take hours manually
      - Standard CRUD features: Minutes instead of hours
      - Integrations with common APIs: AI knows the patterns, minimal research needed
      - Testing: AI generates test suites quickly
      - Debugging: AI helps identify and fix issues rapidly

      Because of AI assistance, estimate hours at roughly 20-30% of traditional development time.

      PROJECT SCOPE: #{scope_context[:label]}
      Target total hours: #{scope_context[:min]}-#{scope_context[:max]} hours

      #{repo_context_text.present? ? "EXISTING CODEBASE CONTEXT:\n#{repo_context_text}\n\nUse this codebase context to understand the existing architecture and provide more accurate estimates. Consider:\n- Existing patterns to follow\n- Libraries/frameworks already in use\n- Complexity of the codebase\n" : ""}

      IMPORTANT GUIDELINES:
      1. Generate 2-4 HIGH-LEVEL PHASES only (not granular task lists)
      2. Each phase should represent a logical chunk of work
      3. Hours must fit within the scope range (#{scope_context[:min]}-#{scope_context[:max]} total)
      4. Round hours to reasonable numbers (1, 2, 4, 8, etc.)

      PHASE CATEGORIES (pick 2-4 that apply):
      - Discovery & Setup: Initial research, project setup, environment config (usually 1-2 hrs)
      - Core Development: Main feature implementation with AI assistance
      - Integration & Testing: API integrations, test coverage, QA
      - Polish & Deployment: UI refinements, deployment, documentation

      The hourly rate is $#{hourly_rate}/hour.

      CRITICAL - CUSTOMER-FACING OUTPUT:
      You MUST also generate:
      1. A "requirements_summary" that explains the customer's PROBLEM and how we're SOLVING it (not technical jargon)
      2. A "features_list" array of customer-friendly feature descriptions (what they're getting for their money)

      Respond with valid JSON:
      {
        "title": "Project title",
        "requirements_summary": "Start with the problem the customer is facing, then explain the solution we're building. Write in plain language, not technical jargon. 2-3 paragraphs.",
        "features_list": [
          "AI-powered chat assistant that answers customer questions 24/7",
          "Integration with your existing database to provide accurate responses",
          "Admin dashboard to review and improve AI responses",
          "Analytics showing common customer questions and satisfaction"
        ],
        "suggested_items": [
          {"description": "Phase 1: Discovery & Setup - Brief description", "hours": 1, "category": "Discovery & Setup"},
          {"description": "Phase 2: Core Development - Brief description", "hours": 2, "category": "Core Development"},
          {"description": "Phase 3: Testing & Deployment - Brief description", "hours": 1, "category": "Integration & Testing"}
        ]
      }

      Only respond with valid JSON, no other text.
    PROMPT

    answers_text = answers.map { |q, a| "Q: #{q}\nA: #{a}" }.join("\n\n")

    messages = [
      { role: "system", content: system_prompt },
      { role: "user", content: "Project description:\n\n#{project_description}\n\nClarifying answers:\n\n#{answers_text}" }
    ]

    response = chat(messages, operation: "generate_bid_details")
    parse_json_response(response, default: { "title" => "New Project", "requirements_summary" => "", "features_list" => [], "suggested_items" => [] })
  end

  def scope_hour_ranges(scope)
    case scope
    when "quick_fix"
      { label: "Quick Fix / Tweak", min: 1, max: 4 }
    when "small_feature"
      { label: "Small Feature", min: 4, max: 16 }
    when "medium_feature"
      { label: "Medium Feature", min: 16, max: 40 }
    when "large_feature"
      { label: "Large Feature / Module", min: 40, max: 80 }
    when "full_app"
      { label: "Full Application", min: 80, max: 200 }
    else
      { label: "Small Feature", min: 4, max: 16 }
    end
  end

  def edit_section(section:, current_content:, prompt:, project_context: nil)
    section_instructions = case section
    when "requirements_summary"
      <<~INST
        You are editing the REQUIREMENTS SUMMARY section of a customer-facing proposal.
        This section should:
        - Explain the customer's problem in plain language
        - Describe the solution we're building
        - Be 2-3 paragraphs, professional but accessible
        - NOT include technical jargon or implementation details
      INST
    when "features_list"
      <<~INST
        You are editing the FEATURES LIST of a customer-facing proposal.
        This is an array of features the customer will receive.
        Each feature should:
        - Be a clear, benefit-focused description
        - Start with an action verb when possible
        - Be understandable to non-technical readers

        Return a JSON array of feature strings.
        Example: ["AI-powered chat that answers questions 24/7", "Dashboard to track customer interactions"]
      INST
    when "notes"
      <<~INST
        You are editing the NOTES section of a proposal.
        This may contain additional context, assumptions, or clarifications for the customer.
        Keep it professional and clear.
      INST
    when "internal_notes"
      <<~INST
        You are editing INTERNAL NOTES (admin only, never shown to customer).
        This can contain technical details, concerns, or reminders for the team.
      INST
    else
      "You are editing a section of a project proposal."
    end

    system_prompt = <<~PROMPT
      #{section_instructions}

      PROJECT CONTEXT:
      #{project_context || "Not provided"}

      CURRENT CONTENT:
      #{current_content || "(empty)"}

      USER REQUEST:
      Apply the following edit request to the current content.

      #{section == "features_list" ? "Respond with ONLY a valid JSON array of strings." : "Respond with ONLY the updated content, no explanation."}
    PROMPT

    messages = [
      { role: "system", content: system_prompt },
      { role: "user", content: prompt }
    ]

    response = chat(messages, operation: "edit_section_#{section}")

    if section == "features_list"
      parsed = parse_json_response(response, default: [])
      { success: true, content: parsed }
    else
      { success: true, content: response&.strip }
    end
  rescue => e
    { success: false, error: e.message }
  end

  def suggest_title(project_description)
    prompt = <<~PROMPT
      Based on this project description, suggest a professional, concise title (5-8 words max).
      Return ONLY the title, no quotes or explanation.

      Description: #{project_description}
    PROMPT

    response = chat([{ role: "user", content: prompt }], operation: "suggest_title")
    response&.strip&.gsub(/^["']|["']$/, '')
  rescue => e
    Rails.logger.error("Grok title suggestion failed: #{e.message}")
    nil
  end

  def suggest_system_costs(project_description, answers, existing_infrastructure: [], repo_contexts: [])
    existing_text = if existing_infrastructure.present?
      <<~EXISTING
        EXISTING INFRASTRUCTURE (client already pays for these - DO NOT DUPLICATE):
        #{existing_infrastructure.map { |i| "- #{i}" }.join("\n")}

        CRITICAL: These services are ALREADY RUNNING. Do not suggest the same type of service again.
        For example:
        - If "AppName: Web Service" exists, do NOT suggest "Render Web Service" - it's the same thing
        - If "AppName: PostgreSQL" exists, do NOT suggest separate storage - PostgreSQL handles file storage via ActiveStorage
        - If any database exists, assume it can handle blob/file storage (no need for S3/R2 unless massive scale)
      EXISTING
    else
      "No existing infrastructure identified for this client."
    end

    repo_analysis = if repo_contexts.present?
      analysis = repo_contexts.map do |ctx|
        <<~REPO
          App: #{ctx[:app_name]} (#{ctx[:repo]})
          Languages: #{ctx[:languages]&.keys&.join(", ") || "Unknown"}
          Key files: #{ctx[:key_files]&.join(", ")}
          Directories: #{ctx[:directories]&.first(15)&.join(", ")}
        REPO
      end.join("\n")

      <<~ANALYSIS
        EXISTING CODEBASE ANALYSIS:
        #{analysis}

        Use this to understand what's ALREADY implemented. Look for:
        - config/storage.yml or ActiveStorage = file storage is handled by the database
        - Gemfile with 'aws-sdk-s3' = they already have S3 configured
        - app/jobs/ directory = background jobs are already set up
        - config/initializers/sentry.rb = monitoring already configured
      ANALYSIS
    else
      ""
    end

    system_prompt = <<~PROMPT
      You are an expert infrastructure consultant at a software services company. We are preparing a bid for a CLIENT'S project.

      #{existing_text}

      #{repo_analysis}

      YOUR TASK: Identify ONLY the NEW infrastructure costs the client will incur for this specific project.

      CRITICAL RULES - READ CAREFULLY:

      1. DO NOT DUPLICATE EXISTING SERVICES:
         - If the client has "AppName: Web Service" - they already have hosting, don't add more
         - If the client has "AppName: PostgreSQL" - they have a database AND file storage (Rails ActiveStorage uses the DB)
         - Existing services should be listed with is_new: false, but don't suggest the same category twice

      2. STORAGE RULES:
         - PostgreSQL databases CAN store files via ActiveStorage - no separate S3/R2 needed for most apps
         - Only suggest S3/R2 if: massive file volumes (millions of files), video streaming, or CDN requirements
         - For typical apps with image uploads: the existing PostgreSQL is sufficient

      3. MONITORING RULES:
         - Do NOT suggest paid monitoring (Sentry, Datadog, etc.) as required infrastructure
         - Apps can use built-in Rails logging, free tiers, or self-hosted solutions
         - Only mention monitoring if the client specifically asks for it

      4. ONLY SUGGEST TRULY NEW REQUIREMENTS:
         - LLM API costs if the project involves AI (this IS a new cost)
         - Vector database if doing RAG/embeddings (truly new)
         - Redis ONLY if the project specifically needs caching or background jobs not already set up
         - Email service ONLY if sending transactional emails and no email config exists

      IF THIS PROJECT INVOLVES AI/ML/LLM:
      You MUST include LLM API costs - this is typically the main new cost:
      - OpenAI GPT-4o: ~$5-15 per 1M input tokens, ~$15-45 per 1M output tokens
      - Anthropic Claude: ~$3-15 per 1M input tokens, ~$15-75 per 1M output tokens
      - xAI Grok: ~$5-10 per 1M tokens
      - For typical chatbot (1,000 conversations/month): $20-50/month
      - For high-volume AI (10,000+ conversations): $100-500/month

      RESPOND WITH JSON - only include items that are truly needed:
      [
        {
          "description": "xAI Grok API",
          "monthly_cost": 30.00,
          "category": "AI/LLM Services",
          "is_new": true,
          "note": "Required for AI agent - estimated for ~2,000 conversations/month"
        }
      ]

      If no new infrastructure is needed beyond what exists, return an empty array: []

      BE CONSERVATIVE - only suggest what's truly necessary. The client shouldn't pay for duplicate services or unnecessary add-ons.

      Only respond with valid JSON, no other text.
    PROMPT

    answers_text = answers.map { |q, a| "Q: #{q}\nA: #{a}" }.join("\n\n")

    messages = [
      { role: "system", content: system_prompt },
      { role: "user", content: "Project description:\n\n#{project_description}\n\nClient details and usage estimates:\n\n#{answers_text}" }
    ]

    response = chat(messages, operation: "suggest_system_costs")
    parse_json_response(response, default: [])
  end

  private

  def log_usage(response_data, model, operation)
    return unless response_data.is_a?(Hash)

    usage = response_data["usage"]
    return unless usage

    log = ApiUsageLog.new(
      provider: "grok",
      model: model,
      operation: operation,
      input_tokens: usage["prompt_tokens"],
      output_tokens: usage["completion_tokens"],
      trackable: @trackable,
      app: @app
    )
    log.calculate_cost!
    log.save!
  rescue => e
    Rails.logger.error("Failed to log API usage: #{e.message}")
  end

  def parse_json_response(response, default:)
    # Extract JSON from response (in case there's extra text)
    json_match = response.match(/\[[\s\S]*\]|\{[\s\S]*\}/)
    return default unless json_match

    JSON.parse(json_match[0])
  rescue JSON::ParserError => e
    Rails.logger.error("Grok JSON parse error: #{e.message}\nResponse: #{response}")
    default
  end
end
