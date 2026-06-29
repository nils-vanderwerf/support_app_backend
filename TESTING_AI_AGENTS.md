# Testing: AI Agent Features

## Servers to run

| Server | Command | URL |
|--------|---------|-----|
| Backend (Rails) | `PORT=9292 rails s` | http://localhost:9292 |
| Frontend (React) | `npm start` (in `support_app_frontend/`) | http://localhost:3000 |

Both servers must be running for the Progress Report feature. The Credential Expiry feature only needs the backend.

---

## 1. Client Progress Report Agent

**Requires:** both servers running, logged in as an approved support worker.

1. Open http://localhost:3000 and log in as a support worker
2. Go to any client profile page
3. Click the **Progress Report** button in the top-right action bar
4. In the drawer, click **Generate Progress Report**
5. The AI generates a markdown summary across all visit reports for that client

If the client has no visit reports yet, you'll get a friendly "No visit reports recorded" message instead.

### Seeded clients with visit reports

Running `rails db:seed` now populates visit reports for all clients with past appointments:

| Client | Worker | Reports |
|--------|--------|---------|
| Elena Martinez | Olivia Williams | 5 |
| Mai Nguyen | Nathan Kowalski | 2 |
| Sophie Chen | Mei Zhang | 3 |
| Amina Ali | Priya Sharma | 2 |
| Raj Patel | James Smith | 2 |
| Thomas Rivera | Olivia Williams | 2 |

**Raj Patel** (no visit reports in the edge-case example below) has been replaced by any client not in the table above.

### To add more visit reports via Rails console

```ruby
client = Client.find_by(first_name: 'Mai')
worker = SupportWorker.find_by(first_name: 'Nathan')

appt = Appointment.create!(client: client, support_worker: worker, date: 1.week.ago, duration: 60, status: 'approved')
VisitReport.create!(appointment: appt, user_id: worker.user_id, client_id: client.id, date: appt.date,
  activities:      'Meal prep, medication reminder, light exercise indoors.',
  observations:    'Client reported improved sleep. Engaged and positive mood.',
  follow_up_actions: 'Review medication if GP recommends changes.')
```

### Expected good output

After clicking **Generate Progress Report** for Elena Martinez, you should get something like:

```
## Overall Progress
Elena has shown consistent progress across five visits over the past month...

## Recurring Observations or Concerns
Morning dizziness was noted in the second visit but resolved after adjusting medication timing...

## Outstanding Follow-up Actions
- Review support plan and consider reducing session frequency given strong progress

## Recommendations
Continue weekly community outings. Confirm upcoming GP check-up to monitor hypertension...
```

### Expected output — no reports (edge case)

Generate the report for a client with no visit reports (e.g. James O'Brien). You should see:

```
No visit reports have been recorded for James O'Brien yet.
```

---

## 1b. Booking Agent — example chat inputs and outputs

**Requires:** both servers running. Open the Booking Agent from the Home page.

### How to see what tools the agent calls

A debug log line is already added to `execute_tool` in [app/controllers/api/ai_booking_controller.rb](app/controllers/api/ai_booking_controller.rb). Every time the agent invokes a tool you will see a line like this printed to the **backend terminal** (the one running `PORT=9292 rails s`):

```
AI tool call: get_support_workers input={"keyword"=>"epilepsy disability"}
AI tool call: open_conversation input={"person_id"=>3}
```

The three possible tool names are:
- `get_support_workers` — agent is searching for workers (client-side flow)
- `get_clients` — agent is searching for clients (worker-side flow)
- `open_conversation` — agent has chosen a match and is opening the chat

If you don't see any tool call lines, the agent responded directly from its own knowledge without hitting the database — that usually means the input was too vague or off-topic.

The `input=` part shows what the agent decided to search for. If it passes a `keyword` that looks wrong or too broad, that's the signal to refine your system prompt or test with a clearer input.

---

### Good inputs (client side)

**Input:** `I have epilepsy and need help with daily living and medication reminders in Sydney`

Expected behaviour: agent calls `get_support_workers`, recommends **Olivia Williams** (Disability Support, Sydney), explains why she's a good match for location and specialisation.

---

**Input:** `I'm looking for mental health support`

Expected behaviour: agent recommends **John Smith** (Mental Health Support, Melbourne) but **flags the distance** if the client is in Sydney — something like "John is based in Melbourne which may be too far, but if you're open to remote support I can connect you."

---

### Bad / edge-case inputs (client side)

**Input:** `help`

Expected behaviour: agent asks a clarifying question — "I'd love to help! Could you tell me a bit more about what kind of support you're looking for and where you're based?"

---

**Input:** `Can you book me a flight to Paris?`

Expected behaviour: agent politely redirects — "I can only help with finding disability support workers on this platform. What kind of support are you looking for?"

---

**Input:** `I need a paediatric nurse who speaks Mandarin`

Expected behaviour: agent calls `get_support_workers`, finds no match, and says so honestly — "I wasn't able to find a worker that matches those specific requirements right now."

---

### Good inputs (support worker side)

**Input:** `I specialise in mental health support and I'm looking for clients who need that kind of help`

Expected behaviour: agent calls `get_clients`, filters by health conditions, surfaces relevant clients.

---

**Input:** `I'm looking for elderly clients near Melbourne`

Expected behaviour: agent surfaces clients near Melbourne; flags any who are in a different city.

---

## 2. Credential Expiry Monitor

### Option A — Rails console (quickest)

Run on the **backend** server:

```bash
rails c
```

```ruby
# Seed a worker with a credential expiring in 30 days
w = SupportWorker.approved.first
w.update!(wwcc_expiry: Date.today + 30)

# Run the job
CredentialExpiryJob.perform_now
# Sends a worker warning email + admin digest
```

Check the Rails server logs — in development, ActionMailer prints emails to stdout instead of sending them.

### Option B — cron endpoint (tests the full production path)

Start the backend (`PORT=9292 rails s`), then in a separate terminal:

```bash
# Set a secret (or use whatever is in your .env)
curl -X POST http://localhost:9292/api/cron/credential_expiry \
  -H "Authorization: Bearer your-cron-secret"
# Expected: { "ok": true }
```

Without the header, or with the wrong secret, you should get `401 Unauthorized`.

### Notification milestones

The job only sends emails when a credential expires in **exactly 30, 14, or 7 days**. To test a specific milestone:

```ruby
w.update!(police_check_expiry: Date.today + 14)
CredentialExpiryJob.perform_now
```

---

## Specs

Run the new specs on the **backend**:

```bash
# All three new spec files
bundle exec rspec spec/controllers/client_progress_reports_controller_spec.rb \
               spec/controllers/cron_controller_spec.rb \
               spec/jobs/credential_expiry_job_spec.rb \
               --format documentation
```

---

## Production setup (Render)

1. Add env vars in Render dashboard:
   - `ADMIN_EMAIL` — address that receives the credential expiry digest
   - `CRON_SECRET` — a random secret string (e.g. `openssl rand -hex 32`)

2. Create a Render Cron Job:
   - **Command:** `curl -X POST $BACKEND_URL/api/cron/credential_expiry -H "Authorization: Bearer $CRON_SECRET"`
   - **Schedule:** `0 8 * * *` (daily at 8am UTC)
