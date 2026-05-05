# Suppova — Backend

Rails API for a portfolio project inspired by [Mable](https://mable.com.au), a platform that connects people living with disability to independent support workers.

**Live API:** [https://api.suppova.com](https://api.suppova.com)

The frontend React app lives in a separate repository: [support_app_frontend](https://github.com/nils-vanderwerf/support_app_frontend), deployed at [https://suppova.com](https://suppova.com).

---

## What it does

- REST API consumed by the React frontend
- Session-based authentication using Devise and Rails session cookies
- Role-based access control — clients and support workers have different permissions
- Appointment booking between clients and support workers (admin roles are not currently supported)
- CSRF protection for non-GET requests
- **AI booking agent** — a `POST /api/ai_booking/chat` endpoint that runs a multi-step Claude tool-use loop and returns a plain text reply to the frontend

## Tech stack

- **Ruby on Rails** (API + session support)
- **PostgreSQL** via [Neon](https://neon.tech) (persistent, serverless — survives redeploys)
- **Devise** for user model and password reset token generation
- **Token-based auth** via `Rails.application.message_verifier` — no session cookies
- **Claude API** (Anthropic) for AI booking and vetting agents
- **Resend** for transactional email (SMTP)
- **RSpec** for request specs
- **anthropic gem** + **dotenv-rails** for the AI booking agent

## Backend concepts practised

- MVC architecture
- RESTful API design
- ActiveRecord associations and database design
- ActiveRecord transactions for data integrity
- Role-based access control with a shared `RoleRegistry` concern
- Session-based authentication (cookies, CSRF)
- Encapsulation and modular design
- RSpec request specs with context blocks
- Agentic AI patterns — tool use, multi-step loops, and prompt engineering with the Claude API

## Running locally

Create a `.env` file in the project root (already gitignored):

```
ANTHROPIC_API_KEY=sk-ant-...
RESEND_API_KEY=re_...
FRONTEND_URL=http://localhost:3000
SECRET_KEY_BASE=<any long random string for local dev>
```

Then:

Add your Anthropic API key to a `.env` file in the project root (already gitignored):

```
ANTHROPIC_API_KEY=sk-ant-...
```

Then:

```bash
bundle install
rails db:create db:migrate db:seed
rails s -p 9292
```

API runs on [http://localhost:9292](http://localhost:9292).

The seed file creates demo clients, support workers, and an admin account. Set the admin password via Rails console:

```ruby
User.find_by(email: 'admin@example.com').update!(password: 'your_password')
```

## Deployment

Deployed on Render using Docker. Required environment variables on Render:

| Variable | Description |
|----------|-------------|
| `DATABASE_URL` | Neon PostgreSQL connection string |
| `ANTHROPIC_API_KEY` | Claude API key |
| `RESEND_API_KEY` | Resend API key |
| `MAILER_FROM` | Sender address (e.g. `noreply@suppova.com`) |
| `FRONTEND_URL` | `https://suppova.com` |
| `SECRET_KEY_BASE` | Rails secret key |
| `RAILS_MASTER_KEY` | Rails credentials key |

After first deploy, run seeds via the Render Shell:

```bash
rails db:seed
```

## Running tests

```bash
bundle exec rspec
```
