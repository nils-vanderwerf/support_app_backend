# Support App — Backend

Rails API for a portfolio project inspired by [Mable](https://mable.com.au), a platform that connects people living with disability to independent support workers.

The frontend React app lives in a separate repository: [support_app_frontend](https://github.com/nils-vanderwerf/support_app_frontend).

## What it does

- REST API consumed by the React frontend
- Session-based authentication using Devise and Rails session cookies
- Role-based access control — clients, support workers, and admins each have different permissions
- Full appointment lifecycle: booking → invitation → approval/decline → confirmation message in chat
- Messaging and conversation system between clients and support workers
- **AI booking agent** — multi-step Claude tool-use loop that matches clients with support workers
- **AI vetting agent** — conversational interview that collects and validates support worker credentials before flagging for admin review
- **Admin dashboard API** — scoped stats, worker lists, and appointment management per admin

## Tech stack

- **Ruby on Rails** (API mode with session support)
- **Devise** for authentication
- **SQLite** for development
- **Active Job** for background appointment reminder emails
- **RSpec** for request specs
- **anthropic gem** + **dotenv-rails** for AI agents

## Features implemented

### Authentication & access control
- Session-based auth with CSRF protection
- Status-gated access: pending and rejected workers are blocked from client data, appointments, and AI features at the controller level
- Admin-only endpoints protected by `require_admin` before action

### Appointment system
- Full CRUD with soft delete (`deleted_at`)
- Pending → approved/declined lifecycle with status scoping (`Appointment.active`, `.pending`, `.approved`)
- System messages posted to the conversation thread on approve/decline, formatted in the user's local timezone
- 24-hour reminder emails via `AppointmentReminderJob`

### Messaging
- Conversation threads between client/worker pairs
- System messages (prefixed `[SYS]`) rendered differently in the UI
- Appointment invitations sent and tracked inside conversations

### AI booking agent (`POST /api/ai_booking/chat`)
- Runs a multi-step tool-use loop in a single HTTP request
- Tools: `get_support_workers`, `get_clients`, `open_conversation`
- Blocked for pending/rejected workers

### AI vetting agent (`POST /api/vetting/chat`)
- Collects police check number, WWCC number, bio, experience, specializations, and availability
- Validates reference numbers (minimum 6 characters, must contain a digit — rejects plain words)
- Extracts structured data and saves to the `support_workers` record on completion
- Sets status to `needs_review` and flags for admin

### Admin dashboard
- `GET /api/admin/stats` — approved workers, pending applicants, total clients, and appointments this week — all scoped to workers that admin personally approved
- `GET /api/admin/workers` — only workers this admin approved
- `GET /api/admin/appointments` — only appointments involving this admin's workers
- `GET /api/admin/applications` — pending applicants across the platform
- `PATCH /api/admin/applications/:id/approve` — sets status to `approved`, records `approved_by_id`
- `PATCH /api/admin/applications/:id/reject`

## Backend concepts practised

- MVC architecture and RESTful API design
- ActiveRecord associations, scopes, and database design
- Role-based and status-based access control
- Admin scoping via foreign key (`approved_by_id`) — each admin sees only their own workers and derived stats
- Timezone-aware date formatting with `in_time_zone` using the client-supplied timezone string
- Session-based authentication (cookies, CSRF)
- Background jobs with Active Job
- RSpec request specs with multi-actor scenarios (two admins, cross-admin isolation)
- Agentic AI patterns — tool use, multi-step loops, prompt engineering, structured data extraction

## Running the app

Add your Anthropic API key to a `.env` file in the project root (already gitignored):

```
ANTHROPIC_API_KEY=sk-ant-...
```

Then:

```bash
bundle install
rails db:create db:migrate db:seed
rackup -p 9292
```

API runs on [http://localhost:9292](http://localhost:9292).

Default admin account: `admin@example.com` / `admin123`

## Running tests

```bash
bundle exec rspec
```
