# Support App Backend — Suppova Support Platform

Rails API backend for the Suppova Support platform.

## Stack

- Ruby on Rails (API mode)
- SQLite (development/test), PostgreSQL (production)
- Devise for authentication
- Sidekiq / ActiveJob for background jobs (appointment reminders)
- Resend (SMTP) for transactional email
- RSpec for testing

## Testing

**Always write specs for any feature change — do not ask first.**

- Specs live in `spec/controllers/` as request specs (`type: :request`)
- Run the full suite: `bundle exec rspec --format documentation`
- Run a single file: `bundle exec rspec spec/controllers/appointments_controller_spec.rb --format documentation`
- Every new controller action needs at minimum: happy path, unauthorized (no login), and forbidden (wrong user) cases
- Auth guards (`authorize_appointment!`, `authorize_conversation!`) must have specs proving a third party gets 403

## Architecture notes

- All appointment queries must use the `active` scope (`deleted_at: nil`) — soft-deleted records are never shown to users
- Conversations and messages are authorized by checking `current_user.client&.id == conversation.client_id || current_user.support_worker&.id == conversation.support_worker_id`
- Appointment mutations (approve/decline/update/destroy) check the same party condition via `authorize_appointment!`
- Experience is stored as an integer (years); free-text values were migrated out
- Dates from the AI are ISO 8601 with timezone offset — parse with `DateTime.parse`, not `Time.parse`, to preserve local time

## Migrations

New migrations run automatically on deploy via `db:migrate`. Data cleanup logic (e.g. extracting integers from text fields) lives in the migration `up` block.

## Data model notes

- `Appointment` is soft-deleted via `deleted_at` — never hard-delete, always set `deleted_at: Time.current`. The `active` scope filters these out.
- `Appointment.approved` and `Appointment.pending` both chain from `active`, so they exclude soft-deleted records automatically.
- `SupportWorker.experience` is an integer (years). It was previously free text — migrated via regex extraction.
- `SupportWorker` has `qualification` (degree type, from a fixed list), `field_of_study` (free text), and `institution` (free text, entered via Google Places API on the frontend).
- `Client` and `SupportWorker` both have `date_of_birth` (replaces the old `age` column). Age is computed from this.
- Conversations are encrypted end-to-end — `encrypt_content` / `decrypt_content` helpers in the controller handle this. Never store or return raw message content directly.

## AI / conversation flow

- `conversations#ai_respond` simulates the *other* party in the conversation (if a client is logged in, the AI plays the support worker, and vice versa).
- The AI can return JSON actions embedded in its response: `send_invitation`, `send_recurring_invitations`, `approve`, `decline`, `decline_all`.
- Dates from the AI are ISO 8601 with timezone offset (e.g. `"2026-05-20T09:30:00+10:00"`). Always parse with `DateTime.parse` — not `Time.parse` or `ActiveSupport::TimeZone` — to preserve the local time offset.
- System messages in conversations are prefixed `[SYS]` and rendered differently on the frontend.

## Deployment

- Backend is deployed on Render. New deploys run `db:migrate` automatically.
- Required env vars: `ANTHROPIC_API_KEY`, `RESEND_API_KEY`, `FRONTEND_URL=https://kindredsupport.vercel.app`, `MAILER_FROM=onboarding@resend.dev`
- Frontend is deployed on Vercel (separate repo at `support_app_frontend`).

## Working style

- This is a learning project. For non-trivial features, ask questions before writing code so the developer can think through the approach first. For bug fixes, small cleanups, and spec additions it's fine to just do it.
- When running parallel fixes, use git worktrees (`isolation: "worktree"` in agent calls) to avoid conflicts.
