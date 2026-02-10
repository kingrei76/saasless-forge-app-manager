# SaaSless Forge — App Management Admin

A standalone Ruby on Rails 7.2 application for managing apps, clients, billing, infrastructure, and projects.

---

## Stack

- **Ruby 3.3.4 / Rails 7.2** — MVC framework
- **PostgreSQL 16** — database
- **Redis** — ActionCable in production
- **Devise** — authentication
- **Pundit** — authorization
- **Stripe** — billing & invoicing
- **SolidQueue** — background jobs (database-backed)
- **Tailwind CSS + DaisyUI** — UI (loaded from CDN, not gems)
- **Importmap** — JavaScript module loading (no Node build step)
- **Stimulus** — JavaScript controllers
- **Turbo** — Hotwire page updates

---

## Project Structure

```
app/
  controllers/
    admin/           # All admin CRUD controllers
    api/             # External API endpoints
    users/           # OAuth callbacks, registrations
  models/            # ActiveRecord models
  views/
    admin/           # Admin views (uses admin.html.erb layout)
    devise/          # Auth views
    layouts/         # application.html.erb, admin.html.erb, print.html.erb
  services/          # Business logic (Stripe, GitHub, Render, billing)
  jobs/              # SolidQueue background jobs
  helpers/
  javascript/
    controllers/     # Stimulus controllers

config/
  routes.rb          # All routes; admin namespace at /admin
  database.yml       # PostgreSQL config
  importmap.rb       # JS module pinning
  puma.rb            # Web server config
  environments/      # development.rb, production.rb, test.rb
  initializers/      # stripe.rb, solid_queue.rb, active_record_encryption.rb

db/
  migrate/           # All migrations
  schema.rb          # Current schema
  seeds.rb           # Default admin user + settings

spec/                # RSpec tests
bin/                 # Rails binstubs + Docker helper scripts
```

---

## Running the App

### Docker (recommended)
```bash
cp .env.example .env   # fill in secrets
docker compose up -d
open http://localhost:3000
```

### Local
```bash
cp .env.example .env
bundle install
bin/rails db:prepare
bin/rails server
```

### Helper Scripts
```bash
bin/dev              # docker compose up -d
bin/rails_bash       # shell into web container
bin/rails_console    # Rails console
bin/rails_logs       # tail web logs
bin/restart          # restart web service
```

---

## Key Patterns

- **Admin namespace**: All admin controllers inherit from `Admin::BaseController` which enforces authentication and admin role.
- **Root route**: `root "admin/dashboard#index"` — Devise redirects unauthenticated users to sign-in.
- **Layouts**: Admin views use `layouts/admin.html.erb`; other views use `layouts/application.html.erb`.
- **Background jobs**: Use SolidQueue (database-backed). Jobs defined in `app/jobs/`, recurring schedule in `config/recurring.yml`.
- **Stripe integration**: Webhook at `POST /webhooks/stripe`. Services in `app/services/stripe_*.rb`.
- **Dev auth bypass**: Set `SKIP_AUTH=true` in `.env` for dev login at `/dev_login`.
- **API authentication**: Bearer token via `api_token` field on User model.

---

## Environment Variables

See `.env.example` for the full list. Key variables:
- `DATABASE_URL` / `POSTGRES_PASSWORD` — database connection
- `SECRET_KEY_BASE` — Rails secret
- `STRIPE_API_KEY`, `STRIPE_PUBLISHABLE_KEY`, `STRIPE_WEBHOOK_SECRET` — Stripe billing
- `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` — OAuth
- `ACTIVE_RECORD_ENCRYPTION_*` — encrypted attributes
- `REDIS_URL` — ActionCable in production
- `SKIP_AUTH` — dev auth bypass

---

## Deployment

The app includes a `Dockerfile` for containerized deployment. For Render:
- `config/environments/production.rb` includes `RENDER_EXTERNAL_HOSTNAME` host allowlisting
- `config/database.yml` production uses `DATABASE_URL`
- Static files are served by Rails (`config.public_file_server.enabled = true`)
