# Suppova — Backend

Rails API for Suppova — a full-stack NDIS support platform connecting clients with verified support workers.

**Live API:** [https://api.suppova.com](https://api.suppova.com)

The frontend React app lives in a separate repository: [support_app_frontend](https://github.com/nils-vanderwerf/support_app_frontend), deployed at [https://suppova.com](https://suppova.com).

---

## What it does

- REST API consumed by the React frontend
- Token-based authentication — signed token returned on login, sent as `Authorization: Bearer` header
- Role-based access control — clients, support workers, and admins each have different permissions
- Full appointment lifecycle: booking → invitation → approval/decline → confirmation message in chat
- Messaging and conversation system between clients and support workers with AES-256-GCM encryption
- **AI conversation simulation** — Claude personas built from real profile data play each participant in a thread
- **AI booking agent** — multi-step Claude tool-use loop that matches clients with support workers
- **AI vetting agent** — conversational interview that collects and validates support worker credentials before flagging for admin review
- **AI visit report drafts** — generates structured Activities, Observations, and Follow-up Actions from appointment context
- **Star ratings & reviews** — clients rate and review support workers after appointments; workers notified by email and in-thread system message
- **Admin dashboard API** — scoped stats, worker lists, and appointment management
- **Transactional email** via Resend — password reset, vetting notifications, and review alerts

## Tech stack

- **Ruby on Rails** (API-only)
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

### Visit reports
- `GET /api/visit_reports` — returns all reports for the authenticated support worker, including client name and date of birth
- `POST /api/visit_reports` — creates a report linked to a specific appointment
- `PUT /api/visit_reports/:id` — updates an existing report
- `POST /api/visit_reports/generate_draft` — calls Claude with appointment and client context to generate structured Activities, Observations, and Follow-up Actions
- `GET /api/clients/:id/visit_reports` — returns visit reports for a specific client; clients see all their own reports (with support worker name); approved workers see only their own reports for that client, gated behind an approved appointment

### Progress reports
- `POST /api/client_progress_reports` — generates an AI summary of a client's full visit history using Claude. Gated behind an approved appointment between the requesting worker and the client
- `GET /api/progress_reports` — returns all progress reports saved by the authenticated support worker, with client name included
- `POST /api/progress_reports` — saves a generated progress report for later reference
- `DELETE /api/progress_reports/:id` — deletes a saved progress report; scoped to the owner (other workers' reports return 404)

### Reviews
- `GET /api/support_workers/:id/reviews` — returns all reviews for a worker, ordered newest first, with client name included
- `POST /api/reviews` — creates a review; client-only, validated against appointment ownership; triggers a `ReviewMailer` email and posts a star-rating system message to the worker's conversation thread
- `PATCH /api/reviews/:id` — updates rating and comment; scoped to the reviewing client (other clients get 403)
- `DELETE /api/reviews/:id` — deletes the review; scoped to the reviewing client

### AI booking agent (`POST /api/ai_booking/chat`)
- Runs a multi-step tool-use loop in a single HTTP request
- Tools: `get_support_workers`, `get_clients`, `open_conversation`
- Returns `tool_calls: [{ name, input }]` in the response so the frontend can render visual step indicators
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

## How the pieces talk to each other

### Frontend ↔ backend

Plain REST/JSON over HTTPS — no GraphQL, no websockets. The React app authenticates with a signed token (`Rails.application.message_verifier`, not a session cookie) stored in `localStorage`, sent as `Authorization: Bearer <token>` on every request via an Axios interceptor. **Trade-off:** no cookies means no CSRF surface at all (CSRF protection is disabled outright in `ApplicationController`), but a token in `localStorage` is readable by any script that runs on the page — an XSS bug becomes a stolen-session bug. Cookie + CSRF-token would flip that trade the other way. For a project with no third-party script inclusion, this was judged the simpler, lower-risk option.

### Third-party APIs — two very different trust models

- **Google Places** (`react-google-maps/api`) is called **directly from the browser** — the frontend holds its own Maps API key and geocodes/autocompletes addresses client-side (`LocationAutocomplete.tsx`, `geoDistance.ts`). The backend never sees this traffic. This key is safe to expose because it's restricted by HTTP referrer in Google Cloud Console, not by secrecy.
- **Claude (Anthropic)** is the opposite: the API key lives only in the backend's environment and is never sent to, or reachable from, the browser. Every AI feature — booking agent, vetting chat, conversation persona simulation, visit/progress report drafting — is a server-side call. This matters because Anthropic calls cost real money per request and can be abused (prompt injection, scraping); putting the key in the browser would hand that risk to anyone who opens devtools.
- One consequence of this split: **distance is computed two different ways.** The support-worker/client list pages compute real Haversine distance from geocoded coordinates (precise, client-side). The AI booking assistant instead asks Claude to estimate distance from place names using its own geographic knowledge (approximate, server-side) — because the tool-use loop doesn't have access to the browser's geocoding. It's a deliberate inconsistency, not an oversight: wiring geocoding into the booking agent's tool results was judged more complexity than the accuracy gain was worth for a fuzzy "is this too far?" check.

### Sensitive data is gated in the backend, never trusted to the frontend

Every access rule — "is this worker approved," "does this worker have an approved appointment with this client," "is this my own report" — is enforced in Rails, not React. Concretely:

- `WorkerApprovalGate` (a concern included in `Api::ApplicationController`) denies any non-approved worker by default via a global `before_action`, before a controller action's own code runs at all. Controllers opt out explicitly (`skip_worker_approval_check`) for the few legitimate exceptions (own profile, the vetting flow itself, admin appeals).
- `Client::PUBLIC_ATTRIBUTES` + `Client#as_json_for(full:)` decide, server-side, exactly which attributes go out in the JSON response — a worker without an approved appointment gets name/age/location/bio/health_conditions/medication/allergies; contact info (phone, email) only serializes once `SupportWorker#approved_appointment_with?(client)` is true.
- **Why this matters:** the frontend's conditional rendering (e.g. `{(editing || client.phone) && ...}` in `ClientProfilePage.tsx`) is UX polish, not a security boundary. Hitting the API directly with curl, a modified frontend build, or browser devtools gets exactly the same restricted JSON, because the decision is made by the server reading the authenticated user's role and relationship to the record — never by a flag or field the client could tamper with. This is the standard defence against "just disable the button in devtools" style attacks.

### Graceful degradation when Claude is unavailable

Every controller that calls Anthropic rescues the call and returns a typed error (`{ error: 'ai_unavailable' }`, `503`) rather than letting a raw exception surface as an unhandled `500`. What the frontend does with that varies by whether a manual fallback makes sense:

- **Progress reports** — the summary field is a normal, always-editable text box from the moment the drawer opens, whether or not AI generation ever runs. A failed AI call just means the box stays empty instead of pre-filled; the worker can still write and save a report by hand.
- **AI booking chat** — there's no manual equivalent to a multi-turn matching conversation, so the fallback is a clearer error plus a direct link to browse the client/support-worker list instead (role-aware: `/support-workers` for clients, `/clients` for workers).
- The booking agent's tool-calling loop is also capped (`MAX_TOOL_ITERATIONS`) — without it, a model that keeps calling tools instead of answering would loop until an infra-level timeout, burning API calls the whole time.

### Message encryption — what it actually protects against

Messages are AES-256-GCM encrypted with a key derived via HKDF-SHA256, and the frontend encrypts before sending / decrypts on render (`src/utils/encryption.ts`). Worth being precise about what this buys: the key is derived from a **hardcoded context string plus the conversation id** — no secret is exchanged between client and server, and the backend independently derives the identical key (it has to, since `ai_respond`/`suggest_booking` need plaintext transcripts to hand to Claude). So this is genuine, correctly-implemented encryption **at rest** — a raw database dump or a misconfigured read replica shows ciphertext, not conversations — but it is not confidentiality against the server itself, which was never the goal here since the AI features require server-side plaintext access anyway. Calling this "end-to-end encrypted" (as some comments in this codebase do) overstates it slightly; "encrypted in transit and at rest, decryptable by both ends because the derivation is public" is the accurate description.

### A few other decisions worth knowing about

- **Two-layer double-booking prevention:** `Appointment` has both a Ruby-level overlap validation (fast, friendly error message) and a Postgres exclusion constraint (the actual source of truth under concurrent requests, which the Ruby check alone can't guarantee). `Appointment#save` rescues the specific `ActiveRecord::StatementInvalid` the constraint raises and turns it into a normal validation error — while still re-raising anything else, so an unrelated DB failure isn't misreported as "just a scheduling conflict."
- **Timezone correctness:** appointment times are rendered in *each account's own* timezone (inferred server-side from their location string via `AU_STATE_TIMEZONES`), not the timezone of whichever browser happens to be viewing them — otherwise a Perth-based worker and a Sydney-based client would see two different, both-wrong times for the same appointment.
- **SQLite in dev/test, Postgres (Neon) in production:** fast local iteration and zero setup versus production parity. The trade-off surfaced directly in this codebase once already — a seed script bug (`db/seeds.rb` referencing a column a migration had renamed) went unnoticed until seeding was actually re-run, since SQLite and Postgres don't diverge on that kind of error either way; it's a trade-off about setup friction, not a false sense of safety.

## Backend concepts practised

- MVC architecture
- RESTful API design
- ActiveRecord associations and database design
- ActiveRecord transactions for data integrity
- Role-based access control with a shared `RoleRegistry` concern
- Token-based authentication (signed tokens, no session cookies)
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

```bash
bundle install
rails db:create db:migrate db:seed
rails s -p 9292
```

API runs on [http://localhost:9292](http://localhost:9292).

The seed file creates demo clients, support workers, and an admin account. All seeded accounts use `password123`. Demo account emails are listed in the [frontend README](https://github.com/nils-vanderwerf/support_app_frontend#demo-accounts).

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
