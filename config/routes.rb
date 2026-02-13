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

    # Infrastructure (unified page for Render Services + Service Providers + Usage)
    resource :infrastructure, only: [:show], controller: "infrastructure" do
      post :sync_render
      post :assign_api_logs
      resources :service_providers, only: [:create, :update, :destroy] do
        member do
          post :sync_now
        end
      end
    end

    # Keep render_services routes for link/unlink actions (used by turbo streams)
    resources :render_services, only: [] do
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
      end
    end

    # Billing actions
    post "billing/generate_monthly", to: "billing#generate_monthly", as: :generate_monthly_billing
    post "billing/process_recurring", to: "billing#process_recurring", as: :process_recurring_billing
    post "billing/generate_recurring_drafts", to: "billing#generate_recurring_drafts", as: :generate_recurring_drafts
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
  end
end
