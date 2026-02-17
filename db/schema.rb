# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_02_16_300001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "agent_alerts", force: :cascade do |t|
    t.bigint "agent_id"
    t.bigint "agent_execution_id"
    t.bigint "agent_execution_step_id"
    t.string "alert_type", null: false
    t.string "severity", default: "info", null: false
    t.string "title", null: false
    t.text "description"
    t.string "status", default: "open", null: false
    t.datetime "resolved_at"
    t.bigint "resolved_by_id"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_execution_id"], name: "index_agent_alerts_on_agent_execution_id"
    t.index ["agent_execution_step_id"], name: "index_agent_alerts_on_agent_execution_step_id"
    t.index ["agent_id"], name: "index_agent_alerts_on_agent_id"
    t.index ["alert_type"], name: "index_agent_alerts_on_alert_type"
    t.index ["resolved_by_id"], name: "index_agent_alerts_on_resolved_by_id"
    t.index ["severity"], name: "index_agent_alerts_on_severity"
    t.index ["status", "severity"], name: "index_agent_alerts_on_status_and_severity"
    t.index ["status"], name: "index_agent_alerts_on_status"
  end

  create_table "agent_execution_steps", force: :cascade do |t|
    t.bigint "agent_execution_id", null: false
    t.integer "step_number", null: false
    t.string "step_type", null: false
    t.bigint "tool_definition_id"
    t.bigint "target_agent_id"
    t.jsonb "input_data", default: {}
    t.jsonb "output_data", default: {}
    t.string "status", default: "pending", null: false
    t.text "error_message"
    t.integer "duration_ms"
    t.integer "tokens_used", default: 0
    t.decimal "cost", precision: 10, scale: 6, default: "0.0"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_execution_id", "step_number"], name: "idx_execution_steps_unique", unique: true
    t.index ["agent_execution_id"], name: "index_agent_execution_steps_on_agent_execution_id"
    t.index ["status"], name: "index_agent_execution_steps_on_status"
    t.index ["step_type"], name: "index_agent_execution_steps_on_step_type"
    t.index ["target_agent_id"], name: "index_agent_execution_steps_on_target_agent_id"
    t.index ["tool_definition_id"], name: "index_agent_execution_steps_on_tool_definition_id"
  end

  create_table "agent_executions", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.bigint "parent_execution_id"
    t.bigint "trigger_id"
    t.string "status", default: "pending", null: false
    t.string "mode", default: "test", null: false
    t.jsonb "state", default: {}
    t.jsonb "input_data", default: {}
    t.jsonb "output_data", default: {}
    t.text "error_message"
    t.jsonb "error_details", default: {}
    t.datetime "started_at"
    t.datetime "completed_at"
    t.integer "total_tokens", default: 0
    t.decimal "total_cost", precision: 10, scale: 6, default: "0.0"
    t.integer "iteration_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "builder_chat_session_id"
    t.index ["agent_id", "created_at"], name: "index_agent_executions_on_agent_id_and_created_at"
    t.index ["agent_id", "status"], name: "index_agent_executions_on_agent_id_and_status"
    t.index ["agent_id"], name: "index_agent_executions_on_agent_id"
    t.index ["builder_chat_session_id"], name: "index_agent_executions_on_builder_chat_session_id"
    t.index ["mode"], name: "index_agent_executions_on_mode"
    t.index ["parent_execution_id"], name: "index_agent_executions_on_parent_execution_id"
    t.index ["status"], name: "index_agent_executions_on_status"
    t.index ["trigger_id"], name: "index_agent_executions_on_trigger_id"
  end

  create_table "agent_goals", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.string "title", null: false
    t.text "description"
    t.text "success_criteria"
    t.integer "priority", default: 0
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_id", "status"], name: "index_agent_goals_on_agent_id_and_status"
    t.index ["agent_id"], name: "index_agent_goals_on_agent_id"
  end

  create_table "agent_handoffs", force: :cascade do |t|
    t.bigint "source_agent_id", null: false
    t.bigint "target_agent_id", null: false
    t.string "name"
    t.text "description"
    t.jsonb "condition", default: {}
    t.integer "priority", default: 0
    t.boolean "enabled", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["source_agent_id", "target_agent_id"], name: "idx_agent_handoffs_unique", unique: true
    t.index ["source_agent_id"], name: "index_agent_handoffs_on_source_agent_id"
    t.index ["target_agent_id"], name: "index_agent_handoffs_on_target_agent_id"
  end

  create_table "agent_memories", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.string "memory_type", default: "fact", null: false
    t.string "key"
    t.text "content", null: false
    t.jsonb "embedding", default: {}
    t.decimal "relevance_score", precision: 5, scale: 4
    t.jsonb "metadata", default: {}
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_id", "key"], name: "idx_agent_memories_key_unique", unique: true, where: "(key IS NOT NULL)"
    t.index ["agent_id", "memory_type"], name: "index_agent_memories_on_agent_id_and_memory_type"
    t.index ["agent_id"], name: "index_agent_memories_on_agent_id"
    t.index ["expires_at"], name: "index_agent_memories_on_expires_at"
  end

  create_table "agent_tools", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.bigint "tool_definition_id", null: false
    t.boolean "enabled", default: true, null: false
    t.boolean "requires_approval", default: false, null: false
    t.jsonb "config", default: {}
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_id", "tool_definition_id"], name: "idx_agent_tools_unique", unique: true
    t.index ["agent_id"], name: "index_agent_tools_on_agent_id"
    t.index ["tool_definition_id"], name: "index_agent_tools_on_tool_definition_id"
  end

  create_table "agent_triggers", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.string "trigger_type", null: false
    t.string "event_name"
    t.bigint "depends_on_agent_id"
    t.string "schedule"
    t.jsonb "condition", default: {}
    t.boolean "enabled", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "tool_definition_id"
    t.integer "check_interval_minutes", default: 60
    t.datetime "last_checked_at"
    t.datetime "last_fired_at"
    t.integer "cooldown_minutes", default: 0
    t.string "webhook_token"
    t.text "description"
    t.jsonb "input_data_template", default: {}
    t.index ["agent_id", "trigger_type"], name: "index_agent_triggers_on_agent_id_and_trigger_type"
    t.index ["agent_id"], name: "index_agent_triggers_on_agent_id"
    t.index ["depends_on_agent_id"], name: "index_agent_triggers_on_depends_on_agent_id"
    t.index ["event_name"], name: "index_agent_triggers_on_event_name"
    t.index ["tool_definition_id"], name: "index_agent_triggers_on_tool_definition_id"
    t.index ["webhook_token"], name: "index_agent_triggers_on_webhook_token", unique: true
  end

  create_table "agent_versions", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.integer "version_number", null: false
    t.text "system_prompt"
    t.jsonb "config_snapshot", default: {}
    t.text "change_summary"
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_id", "version_number"], name: "index_agent_versions_on_agent_id_and_version_number", unique: true
    t.index ["agent_id"], name: "index_agent_versions_on_agent_id"
    t.index ["created_by_id"], name: "index_agent_versions_on_created_by_id"
  end

  create_table "agents", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.text "system_prompt"
    t.string "category", default: "custom", null: false
    t.string "status", default: "draft", null: false
    t.string "mode", default: "test", null: false
    t.integer "version", default: 1, null: false
    t.integer "max_iterations", default: 25
    t.decimal "temperature", precision: 3, scale: 2, default: "0.7"
    t.string "llm_model"
    t.bigint "service_provider_id"
    t.jsonb "config", default: {}
    t.jsonb "memory_config", default: {}
    t.jsonb "metadata", default: {}
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "ai_model_id"
    t.index ["ai_model_id"], name: "index_agents_on_ai_model_id"
    t.index ["category"], name: "index_agents_on_category"
    t.index ["created_by_id"], name: "index_agents_on_created_by_id"
    t.index ["mode"], name: "index_agents_on_mode"
    t.index ["service_provider_id"], name: "index_agents_on_service_provider_id"
    t.index ["slug"], name: "index_agents_on_slug", unique: true
    t.index ["status"], name: "index_agents_on_status"
  end

  create_table "ai_models", force: :cascade do |t|
    t.bigint "service_provider_id", null: false
    t.string "name", null: false
    t.string "model_id", null: false
    t.string "category", default: "chat", null: false
    t.integer "context_window"
    t.integer "max_output_tokens"
    t.decimal "input_price_per_million", precision: 10, scale: 4
    t.decimal "output_price_per_million", precision: 10, scale: 4
    t.jsonb "capabilities", default: {}
    t.string "status", default: "active", null: false
    t.integer "sort_order", default: 0
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_ai_models_on_category"
    t.index ["model_id"], name: "index_ai_models_on_model_id"
    t.index ["service_provider_id", "model_id"], name: "index_ai_models_on_service_provider_id_and_model_id", unique: true
    t.index ["service_provider_id"], name: "index_ai_models_on_service_provider_id"
    t.index ["status"], name: "index_ai_models_on_status"
  end

  create_table "allowed_emails", force: :cascade do |t|
    t.string "email", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_allowed_emails_on_email", unique: true
  end

  create_table "api_usage_logs", force: :cascade do |t|
    t.string "provider", null: false
    t.string "model", null: false
    t.string "operation"
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.decimal "estimated_cost", precision: 10, scale: 6
    t.string "trackable_type"
    t.bigint "trackable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "app_id"
    t.bigint "service_provider_id"
    t.integer "quantity"
    t.string "quantity_unit"
    t.jsonb "metadata", default: {}
    t.string "external_id"
    t.index ["app_id", "created_at"], name: "index_api_usage_logs_on_app_id_and_created_at"
    t.index ["app_id"], name: "index_api_usage_logs_on_app_id"
    t.index ["external_id"], name: "index_api_usage_logs_on_external_id", unique: true, where: "(external_id IS NOT NULL)"
    t.index ["provider", "created_at"], name: "index_api_usage_logs_on_provider_and_created_at"
    t.index ["provider"], name: "index_api_usage_logs_on_provider"
    t.index ["service_provider_id"], name: "index_api_usage_logs_on_service_provider_id"
    t.index ["trackable_type", "trackable_id"], name: "index_api_usage_logs_on_trackable"
  end

  create_table "app_assignments", force: :cascade do |t|
    t.bigint "app_id", null: false
    t.bigint "client_id", null: false
    t.decimal "markup_percentage", precision: 5, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_id", "client_id"], name: "index_app_assignments_on_app_id_and_client_id", unique: true
    t.index ["app_id"], name: "index_app_assignments_on_app_id"
    t.index ["client_id"], name: "index_app_assignments_on_client_id"
  end

  create_table "app_service_configs", force: :cascade do |t|
    t.bigint "app_id", null: false
    t.bigint "service_provider_id", null: false
    t.boolean "enabled", default: true
    t.decimal "monthly_budget_limit", precision: 10, scale: 2
    t.string "external_identifier"
    t.jsonb "config", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_id", "service_provider_id"], name: "idx_app_service_configs_unique", unique: true
    t.index ["app_id"], name: "index_app_service_configs_on_app_id"
    t.index ["service_provider_id"], name: "index_app_service_configs_on_service_provider_id"
  end

  create_table "apps", force: :cascade do |t|
    t.bigint "github_account_id", null: false
    t.string "github_repo_id"
    t.string "name"
    t.string "full_name"
    t.string "url"
    t.text "description"
    t.string "default_branch"
    t.string "language"
    t.string "latest_commit_sha"
    t.string "latest_commit_message"
    t.datetime "latest_commit_at"
    t.boolean "included", default: true
    t.string "status"
    t.jsonb "tags", default: []
    t.jsonb "github_metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "render_service_id"
    t.string "render_service_type"
    t.string "render_plan"
    t.string "render_owner_id"
    t.datetime "render_created_at"
    t.string "ai_api_key"
    t.string "ai_api_provider", default: "grok"
    t.string "github_owner"
    t.string "app_type", default: "client_app", null: false
    t.index ["app_type"], name: "index_apps_on_app_type"
    t.index ["github_account_id"], name: "index_apps_on_github_account_id"
    t.index ["github_owner"], name: "index_apps_on_github_owner"
    t.index ["github_repo_id"], name: "index_apps_on_github_repo_id", unique: true
    t.index ["render_owner_id"], name: "index_apps_on_render_owner_id"
    t.index ["render_service_id"], name: "index_apps_on_render_service_id", unique: true
  end

  create_table "audit_logs", force: :cascade do |t|
    t.bigint "user_id"
    t.string "action", null: false
    t.string "auditable_type"
    t.bigint "auditable_id"
    t.jsonb "changes_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable_type_and_auditable_id"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "bid_apps", force: :cascade do |t|
    t.bigint "bid_id", null: false
    t.bigint "app_id"
    t.string "new_app_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_id"], name: "index_bid_apps_on_app_id"
    t.index ["bid_id"], name: "index_bid_apps_on_bid_id"
  end

  create_table "bid_line_items", force: :cascade do |t|
    t.bigint "bid_id", null: false
    t.string "description"
    t.decimal "hours", precision: 8, scale: 2
    t.decimal "rate", precision: 10, scale: 2
    t.decimal "subtotal", precision: 10, scale: 2
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "line_item_type", default: "development", null: false
    t.decimal "unit_cost", precision: 10, scale: 2
    t.decimal "display_price", precision: 10, scale: 2
    t.boolean "is_recurring", default: false
    t.string "billing_frequency"
    t.bigint "bid_app_id"
    t.string "work_category"
    t.boolean "is_new_system", default: false
    t.string "system_category"
    t.index ["bid_app_id"], name: "index_bid_line_items_on_bid_app_id"
    t.index ["bid_id"], name: "index_bid_line_items_on_bid_id"
    t.index ["line_item_type"], name: "index_bid_line_items_on_line_item_type"
    t.index ["work_category"], name: "index_bid_line_items_on_work_category"
  end

  create_table "bids", force: :cascade do |t|
    t.bigint "client_id"
    t.string "title", null: false
    t.string "status", default: "draft"
    t.decimal "hourly_rate", precision: 10, scale: 2
    t.decimal "total", precision: 10, scale: 2, default: "0.0"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "project_id"
    t.boolean "ai_generated", default: false
    t.text "requirements_summary"
    t.jsonb "wizard_state", default: {}
    t.decimal "estimated_hours_total", precision: 8, scale: 2
    t.decimal "monthly_costs_total", precision: 10, scale: 2, default: "0.0"
    t.string "project_scope", default: "small_feature"
    t.text "internal_notes"
    t.jsonb "features_list", default: []
    t.index ["client_id"], name: "index_bids_on_client_id"
    t.index ["project_id"], name: "index_bids_on_project_id"
  end

  create_table "builder_chat_sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "agent_id"
    t.bigint "builder_agent_id", null: false
    t.jsonb "conversation_memory", default: []
    t.jsonb "context", default: {}
    t.string "status", default: "active", null: false
    t.datetime "last_message_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_id"], name: "index_builder_chat_sessions_on_agent_id"
    t.index ["builder_agent_id"], name: "index_builder_chat_sessions_on_builder_agent_id"
    t.index ["user_id", "agent_id"], name: "idx_builder_chat_active_user_agent", unique: true, where: "((status)::text = 'active'::text)"
    t.index ["user_id"], name: "index_builder_chat_sessions_on_user_id"
  end

  create_table "calculated_costs", force: :cascade do |t|
    t.bigint "app_id", null: false
    t.bigint "client_id", null: false
    t.string "render_service_id"
    t.string "service_type"
    t.string "plan_name"
    t.date "billing_period_start", null: false
    t.date "billing_period_end", null: false
    t.decimal "base_cost", precision: 10, scale: 2, default: "0.0"
    t.decimal "bandwidth_cost", precision: 10, scale: 2, default: "0.0"
    t.decimal "storage_cost", precision: 10, scale: 2, default: "0.0"
    t.decimal "total_cost", precision: 10, scale: 2, default: "0.0"
    t.integer "days_in_period"
    t.integer "days_active"
    t.decimal "prorated_multiplier", precision: 6, scale: 4, default: "1.0"
    t.decimal "projected_monthly_cost", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_id", "client_id", "render_service_id", "billing_period_start"], name: "idx_calculated_costs_lookup", unique: true
    t.index ["app_id"], name: "index_calculated_costs_on_app_id"
    t.index ["client_id", "billing_period_start"], name: "idx_calculated_costs_by_client"
    t.index ["client_id"], name: "index_calculated_costs_on_client_id"
  end

  create_table "clients", force: :cascade do |t|
    t.string "name", null: false
    t.string "email"
    t.string "company"
    t.string "stripe_customer_id"
    t.decimal "markup_percentage", precision: 5, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "billing_anchor"
    t.integer "billing_day_of_month"
    t.string "stripe_subscription_id"
    t.datetime "billing_cycle_last_synced_at"
    t.string "stripe_default_payment_method_id"
    t.string "collection_method", default: "send_invoice"
    t.index ["stripe_subscription_id"], name: "index_clients_on_stripe_subscription_id", unique: true
  end

  create_table "cost_entries", force: :cascade do |t|
    t.bigint "app_id", null: false
    t.string "service_name", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "currency", default: "USD"
    t.date "period_start"
    t.date "period_end"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "source_type"
    t.string "source_id"
    t.index ["app_id"], name: "index_cost_entries_on_app_id"
    t.index ["source_type", "source_id", "period_start"], name: "idx_cost_entries_source_period", unique: true
  end

  create_table "github_accounts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "account_name", null: false
    t.text "access_token"
    t.string "label"
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "render_api_key"
    t.string "render_owner_id"
    t.datetime "render_last_synced_at"
    t.index ["render_owner_id"], name: "index_github_accounts_on_render_owner_id"
    t.index ["user_id"], name: "index_github_accounts_on_user_id"
  end

  create_table "invoice_line_items", force: :cascade do |t|
    t.bigint "invoice_id", null: false
    t.bigint "app_id"
    t.string "description"
    t.decimal "internal_cost", precision: 10, scale: 2
    t.decimal "markup_percentage", precision: 5, scale: 2
    t.decimal "amount", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "hours", precision: 8, scale: 2
    t.decimal "rate", precision: 10, scale: 2
    t.index ["app_id"], name: "index_invoice_line_items_on_app_id"
    t.index ["invoice_id"], name: "index_invoice_line_items_on_invoice_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.string "stripe_invoice_id"
    t.string "status", default: "draft"
    t.date "period_start"
    t.date "period_end"
    t.decimal "subtotal", precision: 10, scale: 2, default: "0.0"
    t.decimal "total", precision: 10, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "project_id"
    t.bigint "bid_id"
    t.string "invoice_type", default: "cost_based"
    t.string "payment_type", default: "full"
    t.decimal "deposit_percentage", precision: 5, scale: 2
    t.decimal "deposit_amount", precision: 10, scale: 2
    t.datetime "deposit_paid_at"
    t.decimal "final_amount", precision: 10, scale: 2
    t.datetime "final_paid_at"
    t.bigint "parent_invoice_id"
    t.bigint "recurring_invoice_id"
    t.string "stripe_hosted_invoice_url"
    t.string "stripe_payment_intent_id"
    t.string "stripe_status"
    t.datetime "paid_at"
    t.date "due_date"
    t.string "collection_method"
    t.index ["bid_id"], name: "index_invoices_on_bid_id"
    t.index ["client_id"], name: "index_invoices_on_client_id"
    t.index ["parent_invoice_id"], name: "index_invoices_on_parent_invoice_id"
    t.index ["payment_type"], name: "index_invoices_on_payment_type"
    t.index ["project_id"], name: "index_invoices_on_project_id"
    t.index ["recurring_invoice_id"], name: "index_invoices_on_recurring_invoice_id"
  end

  create_table "pending_billing_items", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.bigint "app_id"
    t.string "stripe_invoice_item_id", null: false
    t.string "item_type", null: false
    t.string "description"
    t.decimal "internal_cost", precision: 10, scale: 2
    t.decimal "markup_percentage", precision: 5, scale: 2
    t.decimal "billed_amount", precision: 10, scale: 2
    t.date "period_start"
    t.date "period_end"
    t.string "billing_cycle_id"
    t.string "status", default: "pending", null: false
    t.string "stripe_invoice_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_id"], name: "index_pending_billing_items_on_app_id"
    t.index ["client_id", "billing_cycle_id"], name: "index_pending_billing_items_on_client_id_and_billing_cycle_id"
    t.index ["client_id"], name: "index_pending_billing_items_on_client_id"
    t.index ["status"], name: "index_pending_billing_items_on_status"
    t.index ["stripe_invoice_item_id"], name: "index_pending_billing_items_on_stripe_invoice_item_id", unique: true
  end

  create_table "project_apps", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "app_id"
    t.string "new_app_name"
    t.boolean "primary", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_id"], name: "index_project_apps_on_app_id"
    t.index ["project_id", "app_id"], name: "index_project_apps_on_project_id_and_app_id", unique: true, where: "(app_id IS NOT NULL)"
    t.index ["project_id"], name: "index_project_apps_on_project_id"
  end

  create_table "projects", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.string "title", null: false
    t.text "description"
    t.string "status", default: "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "assignee_id"
    t.string "stage", default: "in_development"
    t.date "development_due_date"
    t.date "go_live_date"
    t.date "adoption_due_date"
    t.decimal "estimated_hours", precision: 8, scale: 2
    t.decimal "actual_hours", precision: 8, scale: 2, default: "0.0"
    t.bigint "source_bid_id"
    t.index ["assignee_id"], name: "index_projects_on_assignee_id"
    t.index ["client_id"], name: "index_projects_on_client_id"
    t.index ["source_bid_id"], name: "index_projects_on_source_bid_id"
    t.index ["stage"], name: "index_projects_on_stage"
  end

  create_table "recurring_invoices", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.string "status", default: "draft", null: false
    t.string "collection_method", default: "send_invoice", null: false
    t.integer "days_until_due", default: 30
    t.integer "billing_day_of_month", default: 1
    t.date "next_billing_date"
    t.date "last_billed_date"
    t.string "stripe_payment_method_id"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_recurring_invoices_on_client_id", unique: true
    t.index ["status", "next_billing_date"], name: "index_recurring_invoices_on_status_and_next_billing_date"
  end

  create_table "render_prices", force: :cascade do |t|
    t.string "service_type", null: false
    t.string "plan_name", null: false
    t.decimal "monthly_price", precision: 10, scale: 2, null: false
    t.decimal "bandwidth_overage_per_gb", precision: 10, scale: 4
    t.decimal "storage_overage_per_gb", precision: 10, scale: 4
    t.integer "included_bandwidth_gb"
    t.integer "included_storage_gb"
    t.date "effective_from", null: false
    t.date "effective_until"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["service_type", "plan_name", "effective_from"], name: "idx_render_prices_lookup", unique: true
  end

  create_table "render_services", force: :cascade do |t|
    t.bigint "app_id"
    t.string "render_service_id", null: false
    t.string "name", null: false
    t.string "service_type"
    t.string "plan"
    t.string "render_owner_id"
    t.datetime "render_created_at"
    t.boolean "suspended", default: false
    t.jsonb "raw_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_id", "service_type"], name: "index_render_services_on_app_and_type"
    t.index ["app_id"], name: "index_render_services_on_app_id"
    t.index ["render_owner_id"], name: "index_render_services_on_render_owner_id"
    t.index ["render_service_id"], name: "index_render_services_on_render_service_id", unique: true
    t.index ["service_type"], name: "index_render_services_on_service_type"
  end

  create_table "render_usage_metrics", force: :cascade do |t|
    t.bigint "app_id", null: false
    t.string "render_service_id", null: false
    t.string "metric_type", null: false
    t.decimal "value", precision: 15, scale: 4, null: false
    t.string "unit", null: false
    t.datetime "period_start", null: false
    t.datetime "period_end", null: false
    t.jsonb "raw_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_id", "render_service_id", "metric_type", "period_start"], name: "idx_render_usage_metrics_lookup", unique: true
    t.index ["app_id"], name: "index_render_usage_metrics_on_app_id"
    t.index ["metric_type"], name: "index_render_usage_metrics_on_metric_type"
    t.index ["render_service_id"], name: "index_render_usage_metrics_on_render_service_id"
  end

  create_table "render_workspaces", force: :cascade do |t|
    t.string "render_owner_id", null: false
    t.string "name", null: false
    t.string "email"
    t.string "workspace_type"
    t.string "plan_type"
    t.integer "user_count"
    t.jsonb "raw_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["render_owner_id"], name: "index_render_workspaces_on_render_owner_id", unique: true
  end

  create_table "service_providers", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "category", null: false
    t.string "base_url"
    t.string "api_key"
    t.string "usage_api_key"
    t.jsonb "pricing_rules", default: {}
    t.string "sync_adapter"
    t.jsonb "sync_config", default: {}
    t.boolean "proxy_enabled", default: false
    t.boolean "sync_enabled", default: false
    t.boolean "active", default: true
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_service_providers_on_slug", unique: true
  end

  create_table "settings", force: :cascade do |t|
    t.string "key", null: false
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_settings_on_key", unique: true
  end

  create_table "time_entries", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "user_id", null: false
    t.date "entry_date", null: false
    t.decimal "hours", precision: 6, scale: 2, null: false
    t.string "work_category", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "entry_date"], name: "index_time_entries_on_project_id_and_entry_date"
    t.index ["project_id"], name: "index_time_entries_on_project_id"
    t.index ["user_id"], name: "index_time_entries_on_user_id"
    t.index ["work_category"], name: "index_time_entries_on_work_category"
  end

  create_table "tool_credentials", force: :cascade do |t|
    t.bigint "tool_definition_id", null: false
    t.string "name", null: false
    t.string "credential_type", default: "api_key", null: false
    t.text "encrypted_value"
    t.jsonb "config", default: {}
    t.datetime "expires_at"
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_tool_credentials_on_status"
    t.index ["tool_definition_id", "name"], name: "idx_tool_credentials_unique", unique: true
    t.index ["tool_definition_id"], name: "index_tool_credentials_on_tool_definition_id"
  end

  create_table "tool_definitions", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.string "handler_class"
    t.string "category", default: "other", null: false
    t.jsonb "input_schema", default: {}
    t.jsonb "output_schema", default: {}
    t.integer "version", default: 1, null: false
    t.string "risk_level", default: "low", null: false
    t.string "status", default: "active", null: false
    t.jsonb "config", default: {}
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_tool_definitions_on_category"
    t.index ["risk_level"], name: "index_tool_definitions_on_risk_level"
    t.index ["slug"], name: "index_tool_definitions_on_slug", unique: true
    t.index ["status"], name: "index_tool_definitions_on_status"
  end

  create_table "tool_versions", force: :cascade do |t|
    t.bigint "tool_definition_id", null: false
    t.integer "version_number", null: false
    t.text "description"
    t.jsonb "input_schema", default: {}
    t.jsonb "config_snapshot", default: {}
    t.text "change_summary"
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_tool_versions_on_created_by_id"
    t.index ["tool_definition_id", "version_number"], name: "idx_tool_versions_unique", unique: true
    t.index ["tool_definition_id"], name: "index_tool_versions_on_tool_definition_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "twilio_number"
    t.boolean "admin"
    t.string "api_token"
    t.string "provider"
    t.string "uid"
    t.string "avatar_url"
    t.integer "role", default: 0
    t.index ["api_token"], name: "index_users_on_api_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "agent_alerts", "agent_execution_steps"
  add_foreign_key "agent_alerts", "agent_executions"
  add_foreign_key "agent_alerts", "agents"
  add_foreign_key "agent_alerts", "users", column: "resolved_by_id"
  add_foreign_key "agent_execution_steps", "agent_executions"
  add_foreign_key "agent_execution_steps", "agents", column: "target_agent_id"
  add_foreign_key "agent_execution_steps", "tool_definitions"
  add_foreign_key "agent_executions", "agent_executions", column: "parent_execution_id"
  add_foreign_key "agent_executions", "agent_triggers", column: "trigger_id"
  add_foreign_key "agent_executions", "agents"
  add_foreign_key "agent_executions", "builder_chat_sessions"
  add_foreign_key "agent_goals", "agents"
  add_foreign_key "agent_handoffs", "agents", column: "source_agent_id"
  add_foreign_key "agent_handoffs", "agents", column: "target_agent_id"
  add_foreign_key "agent_memories", "agents"
  add_foreign_key "agent_tools", "agents"
  add_foreign_key "agent_tools", "tool_definitions"
  add_foreign_key "agent_triggers", "agents"
  add_foreign_key "agent_triggers", "agents", column: "depends_on_agent_id"
  add_foreign_key "agent_triggers", "tool_definitions"
  add_foreign_key "agent_versions", "agents"
  add_foreign_key "agent_versions", "users", column: "created_by_id"
  add_foreign_key "agents", "ai_models"
  add_foreign_key "agents", "service_providers"
  add_foreign_key "agents", "users", column: "created_by_id"
  add_foreign_key "ai_models", "service_providers"
  add_foreign_key "api_usage_logs", "apps"
  add_foreign_key "api_usage_logs", "service_providers"
  add_foreign_key "app_assignments", "apps"
  add_foreign_key "app_assignments", "clients"
  add_foreign_key "app_service_configs", "apps"
  add_foreign_key "app_service_configs", "service_providers"
  add_foreign_key "apps", "github_accounts"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "bid_apps", "apps"
  add_foreign_key "bid_apps", "bids"
  add_foreign_key "bid_line_items", "bid_apps"
  add_foreign_key "bid_line_items", "bids"
  add_foreign_key "bids", "clients"
  add_foreign_key "bids", "projects"
  add_foreign_key "builder_chat_sessions", "agents"
  add_foreign_key "builder_chat_sessions", "agents", column: "builder_agent_id"
  add_foreign_key "builder_chat_sessions", "users"
  add_foreign_key "calculated_costs", "apps"
  add_foreign_key "calculated_costs", "clients"
  add_foreign_key "cost_entries", "apps"
  add_foreign_key "github_accounts", "users"
  add_foreign_key "invoice_line_items", "apps"
  add_foreign_key "invoice_line_items", "invoices"
  add_foreign_key "invoices", "bids"
  add_foreign_key "invoices", "clients"
  add_foreign_key "invoices", "projects"
  add_foreign_key "invoices", "recurring_invoices"
  add_foreign_key "pending_billing_items", "apps"
  add_foreign_key "pending_billing_items", "clients"
  add_foreign_key "project_apps", "apps"
  add_foreign_key "project_apps", "projects"
  add_foreign_key "projects", "clients"
  add_foreign_key "projects", "users", column: "assignee_id"
  add_foreign_key "recurring_invoices", "clients"
  add_foreign_key "render_services", "apps"
  add_foreign_key "render_usage_metrics", "apps"
  add_foreign_key "time_entries", "projects"
  add_foreign_key "time_entries", "users"
  add_foreign_key "tool_credentials", "tool_definitions"
  add_foreign_key "tool_versions", "tool_definitions"
  add_foreign_key "tool_versions", "users", column: "created_by_id"
end
