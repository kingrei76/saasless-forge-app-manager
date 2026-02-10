# SaaSless Forge — App Management Admin

A standalone Ruby on Rails application for managing apps, clients, billing, and infrastructure.

## Quick Start (Docker)

```bash
cp .env.example .env   # edit with your secrets
docker compose up -d
open http://localhost:3000
```

## Quick Start (Local)

```bash
cp .env.example .env
bundle install
bin/rails db:prepare
bin/rails server
```

## Stack

- **Ruby on Rails 7.2** — MVC web framework
- **PostgreSQL 16** — relational database
- **Redis** — ActionCable (production)
- **Devise** — authentication
- **Pundit** — authorization
- **Stripe** — billing & invoicing
- **SolidQueue** — background jobs
- **Tailwind CSS + DaisyUI** — UI (via CDN)

## Project Structure

```
app/           # Controllers, models, views, jobs, services
config/        # Rails configuration
db/            # Migrations, schema, seeds
bin/           # Rails binstubs and helper scripts
spec/          # RSpec tests
```

## Helper Scripts

```bash
bin/dev              # docker compose up -d
bin/rails_bash       # shell into web container
bin/rails_console    # Rails console in container
bin/rails_logs       # tail web container logs
bin/rails_server     # start Rails server in container
bin/restart          # restart web service
```
