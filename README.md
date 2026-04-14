# Suppova — Backend

Rails API for a portfolio project inspired by [Mable](https://mable.com.au), a platform that connects people living with disability to independent support workers.

**Live API:** [https://api.suppova.com](https://api.suppova.com)

The frontend React app lives in a separate repository: [support_app_frontend](https://github.com/nils-vanderwerf/support_app_frontend), deployed at [https://suppova.com](https://suppova.com).

---

## What it does

- REST API consumed by the React frontend
- Token-based authentication — signed token returned on login, sent as `Authorization: Bearer` header
- Role-based access control — clients, support workers, and admins each have different permissions
- Full appointment lifecycle: booking → invitation → approval/decline → confirmation message in chat
- Messaging and conversation system between clients and support workers with AES-256-GCM encryption
- **AI booking agent** — multi-step Claude tool-use loop that matches clients with support workers
- **AI vetting agent** — conversational interview that collects and validates support worker credentials before flagging for admin review
- **Admin dashboard API** — scoped stats, worker lists, and appointment management
- **Transactional email** via Resend — password reset and vetting application notifications

## Tech stack

- **Ruby on Rails** (API + session support)
- **PostgreSQL** via [Neon](https://neon.tech) (persistent, serverless — survives redeploys)
- **Devise** for user model and password reset token generation
- **Token-based auth** via `Rails.application.message_verifier` — no session cookies
- **Claude API** (Anthropic) for AI booking and vetting agents
- **Resend** for transactional email (SMTP)
- **RSpec** for request specs
- **Docker** — deployed on [Render](https://render.com)

## Features

### Authentication & access control
- Token-based auth — `Authorization: Bearer <token>` on every request; no session cookies or CSRF
- Status-gated access: pending and rejected workers are blocked from client data, appointments, and AI features at the controller level
- Role-scoped browsing: support workers can only browse clients, and clients can only browse support workers
- Admin-only endpoints protected by `require_admin` before action

### Appointment system
- Full CRUD with soft delete (`deleted_at`)
- Pending → approved/declined lifecycle with status scoping (`Appointment.active`, `.pending`, `.approved`)
- System messages posted to the conversation thread on approve/decline, formatted in the user's local timezone

### Messaging
- Conversation threads between client/worker pairs
- All message content encrypted before storage — server stores only ciphertext prefixed `ENC:`
- System messages (prefixed `[SYS]`) rendered differently in the UI

### AI booking agent (`POST /api/ai_booking/chat`)
- Runs a multi-step tool-use loop in a single HTTP request
- Tools: `get_support_workers`, `get_clients`, `open_conversation`
- Blocked for pending/rejected workers

### AI vetting agent (`POST /api/vetting/chat`)
- Collects police check number, WWCC number, and expiry dates
- Validates reference numbers (minimum 6 characters, must contain a digit — rejects plain words)
- Extracts structured data and saves to the `support_workers` record on completion
- Sets status to `pending` and notifies admin via email

### Password reset
- `POST /api/password_resets` — generates a Devise reset token and emails a link via Resend
- `PATCH /api/password_resets/:token` — validates token and updates password
- Reset link points to `FRONTEND_URL/reset-password/:token`

### Admin dashboard
- `GET /api/admin/stats` — approved workers, pending applicants, total clients, appointments this week
- `GET /api/admin/applications` — pending applicants across the platform
- `PATCH /api/admin/applications/:id/approve` — sets status to `approved`, sends approval message to worker's Suppova thread
- `PATCH /api/admin/applications/:id/reject` — notifies worker with reason and reapply instructions
- `GET /api/admin/messages` / `POST /api/admin/messages/:id/reply` — admin messaging with support workers

## Backend concepts practised

- MVC architecture and RESTful API design
- ActiveRecord associations, scopes, and database design
- Role-based and status-based access control
- Token-based authentication without session cookies (cross-domain compatible)
- Timezone-aware date formatting with `in_time_zone`
- RSpec request specs with multi-actor scenarios
- Agentic AI patterns — tool use, multi-step loops, prompt engineering, structured data extraction
- Docker multi-stage builds for production deployment

## Running locally

Create a `.env` file in the project root (already gitignored):

```
ANTHROPIC_API_KEY=sk-ant-...
RESEND_API_KEY=re_...
FRONTEND_URL=http://localhost:3000
SECRET_KEY_BASE=<any long random string for local dev>
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
