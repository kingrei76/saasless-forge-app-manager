Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: 'users/registrations' }

  # OAuth callbacks
  get "/auth/google/callback", to: "users/oauth_callbacks#google"

  # Dev login bypass
  get "dev_login", to: "dev_sessions#create" if Rails.env.development? || ENV["SKIP_AUTH"] == "true"

  resources :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  root "admin/dashboard#index"

  # Stripe webhooks (outside admin namespace, no auth)
  post "webhooks/stripe", to: "stripe_webhooks#create"

  namespace :admin do
    root to: "dashboard#index"

    resources :users do
      member do
        post :impersonate
      end
    end

    resources :github_accounts do
      collection do
        post :sync_all
      end
      member do
        post :test_connection
        post :sync
        post :test_render_connection
        post :sync_render
      end
    end

    resources :apps, only: [:index, :show, :update] do
      member do
        patch :toggle_included
      end
      collection do
        post :sync
      end
      resources :app_service_configs, only: [:create, :update, :destroy]
    end

    resources :clients do
      resources :app_assignments, only: [:create, :destroy, :update]
    end

    resources :cost_entries do
      collection do
        post :sync_render
      end
    end
    resources :costs, only: [:index]

    # Infrastructure (unified page for Render Services + Service Providers + Usage + AI Models)
    resource :infrastructure, only: [:show], controller: "infrastructure" do
      post :sync_render
      post :assign_api_logs
      resources :service_providers, only: [:create, :update, :destroy] do
        member do
          post :sync_now
        end
      end
      resources :ai_models, only: [:create, :update, :destroy]
    end

    # Keep render_services routes for link/unlink actions (used by turbo streams)
    resources :render_services, only: [] do
      collection do
        post :sync
      end
      member do
        post :link
        post :unlink
      end
    end

    resources :projects, except: [:new, :create] do
      member do
        patch :upload_requirements
        patch :upload_signed_contract
        post :advance_stage
        post :complete
        post :link_app
        delete :unlink_app
      end
      resources :time_entries, except: [:show]
    end

    resources :bids do
      resources :line_items, controller: "bid_line_items"
      member do
        post :send, action: :send_bid, as: :send
        post :accept
        post :reject
        post :reopen
        get :preview_pdf
        patch :update_section
      end
    end

    # Bid Wizard (AI-assisted bid creation)
    resources :bid_wizards, only: [:new, :create, :show, :update], controller: "bid_wizard" do
      member do
        post :regenerate_questions
        post :regenerate_suggestions
        post :suggest_costs
        post :back
      end
    end

    resources :invoices do
      resources :line_items, controller: "invoice_line_items"
      member do
        post :send_to_stripe
        post :mark_paid
        post :archive
        post :void_stripe
        post :duplicate_as_draft
        post :sync_stripe
        get :preview_send
      end
    end

    resource :settings, only: [:show, :update]
    post "settings/test_grok_connection", to: "settings#test_grok_connection", as: :test_grok_connection_settings
    resources :audit_logs, only: [:index, :show]

    # Recurring Invoices
    resources :recurring_invoices do
      member do
        post :activate
        post :pause
        post :cancel
        post :setup_payment_method
        post :send_payment_setup
        post :migrate_to_subscription
      end
    end

    # Billing actions
    post "billing/generate_monthly", to: "billing#generate_monthly", as: :generate_monthly_billing
    post "billing/process_recurring", to: "billing#process_recurring", as: :process_recurring_billing
    post "billing/generate_recurring_drafts", to: "billing#generate_recurring_drafts", as: :generate_recurring_drafts

    # Agent Builder Chat
    scope :builder_chat, controller: "builder_chat" do
      get  "/",            action: :show,         as: :builder_chat
      post "send_message", action: :send_message, as: :builder_chat_send
      get  "poll",         action: :poll,         as: :builder_chat_poll
      post "approve",      action: :approve,      as: :builder_chat_approve
      post "reject",       action: :reject,       as: :builder_chat_reject
      delete "clear",      action: :clear,        as: :builder_chat_clear
      get  "session",      action: :session,      as: :builder_chat_session
    end

    # AI Agents
    resources :agents do
      member do
        post :activate
        post :pause
        post :archive
        post :duplicate
        post :toggle_mode
        post :execute
      end
      resources :agent_tools, only: [:create, :update, :destroy] do
        member { patch :toggle }
      end
      resources :agent_handoffs, only: [:create, :update, :destroy]
      resources :agent_goals, only: [:create, :update, :destroy]
      resources :agent_triggers, only: [:create, :update, :destroy] do
        member { post :fire }
      end
      resources :agent_memories, only: [:index, :destroy] do
        collection { delete :purge_expired }
      end
    end
    resources :tool_definitions, only: [:index, :show, :update, :destroy] do
      resources :tool_credentials, only: [:create, :update, :destroy]
      resources :tool_versions, only: [:index]
    end
    resources :agent_executions, only: [:index, :show] do
      member do
        post :approve_step
        post :reject_step
        post :cancel
        post :retry
      end
    end
    resource :agent_dashboard, only: [:show], controller: "agent_dashboard"
    resources :agent_alerts, only: [:index, :show, :update] do
      member do
        post :acknowledge
        post :resolve
        post :dismiss
      end
    end
  end

  post "/stop_impersonating", to: "application#stop_impersonating"

  # API endpoints for external apps
  namespace :api do
    post "ai_usage", to: "ai_usage#create"

    # AI Gateway proxy (OpenAI-compatible)
    scope "ai/v1" do
      post "chat/completions", to: "ai_proxy#chat_completions"
      get  "models",           to: "ai_proxy#models"
    end

    # Services Gateway config
    scope "gateway" do
      get "keys", to: "gateway_config#keys"
    end

    # Trigger schemas (for condition builder UI)
    get "trigger_schemas", to: "trigger_schemas#show"

    # Trigger webhooks (external push triggers)
    post "triggers/:webhook_token", to: "trigger_webhooks#create", as: :trigger_webhook

    # App introspection (for Agent Builder and external tools)
    scope "introspection" do
      get "/",       to: "introspection#index"
      get "events",  to: "introspection#events"
      get "tools",   to: "introspection#tools"
      get "agents",  to: "introspection#agents"
      get "routes",  to: "introspection#routes"
      get "models",  to: "introspection#models"
    end

    # Agent Configuration API
    resources :agents, only: [:index, :show, :create, :update] do
      member do
        post :execute
      end
      resources :tools, controller: "agent_config_tools", only: [:create, :destroy]
      resources :triggers, controller: "agent_config_triggers", only: [:create, :destroy]
      resources :goals, controller: "agent_config_goals", only: [:create, :destroy]
      resources :handoffs, controller: "agent_config_handoffs", only: [:create, :destroy]
    end

    # Agent execution callbacks (from LangGraph microservice)
    scope "agent_callbacks" do
      post "step_completed",   to: "agent_callbacks#step_completed"
      post "approval_needed",  to: "agent_callbacks#approval_needed"
      post "execution_done",   to: "agent_callbacks#execution_done"
      post "error",            to: "agent_callbacks#error"
    end
  end
end
