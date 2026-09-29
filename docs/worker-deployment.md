# Worker deployment

Reminder and Gmail sync work happens in short, stateless runs rather than a
long-lived process. `ReminderService` owns all the scheduling logic and dedupes
through notification dedupe keys, so the only job of a scheduler is to invoke
the worker often enough to land inside each notification window.

| Worker | Window it must hit | Suggested cadence |
| --- | --- | --- |
| `notification_worker` | interview reminder 24h before; follow-up reminder 15 min wide; overdue notice 6h wide starting a day after | every 5 minutes |
| `gmail_sync_worker` | not time-based — user- or schedule-triggered | every 15 minutes, per user |

A tick that fires twice creates nothing the second time, so an extra run is
harmless. That is why the cadence can be aggressive without risking duplicate
notifications.

## Local / single host

`scripts/run_reminders.sh` picks up `backend/.venv` when present and falls back
to `python3`. It is cron-ready:

```cron
*/5 * * * * /absolute/path/to/Job-Tracker/scripts/run_reminders.sh >> /var/log/job-tracker-reminders.log 2>&1
```

Run it once by hand before trusting the schedule — a misconfigured environment
should fail loudly at the terminal rather than quietly in a mail spool.

## Cloud Scheduler + Cloud Run

`notification_worker` takes no arguments, so it maps onto a Cloud Run job. The
Gmail sync worker needs a `<user_id>`, so schedule it per user.

```bash
PROJECT=your-gcp-project
REGION=us-central1
IMAGE="gcr.io/$PROJECT/job-tracker-backend"
JOB=job-tracker-reminders

gcloud run jobs deploy "$JOB" --image "$IMAGE" --region "$REGION" \
  --command python --args "-m,app.workers.notification_worker"

gcloud scheduler jobs create http job-tracker-reminders \
  --location "$REGION" \
  --schedule "*/5 * * * *" \
  --uri "https://run.googleapis.com/v2/jobs/$JOB:run" \
  --http-method POST \
  --oauth-service-account-email "job-tracker-scheduler@$PROJECT.iam.gserviceaccount.com"
```

Give the scheduler service account permission to start the job:

```bash
gcloud run jobs add-invoker-policy "$JOB" \
  --region "$REGION" \
  --member "serviceAccount:job-tracker-scheduler@$PROJECT.iam.gserviceaccount.com"
```

## Required environment

Workers need the same secrets as the API. Prefer Secret Manager references over
literal values:

- `GOOGLE_APPLICATION_CREDENTIALS` — service account JSON with Firestore access
- `ENCRYPTION_KEY` — must match the API's, or stored tokens cannot be decrypted
- `GMAIL_CLIENT_ID` / `GMAIL_CLIENT_SECRET` — required only by `gmail_sync_worker`
- `FIREBASE_PROJECT_ID`, `ENVIRONMENT`, `CORS_ORIGINS` — see `.env.example`

## Operational notes

- A worker run is idempotent, so retrying a failed Cloud Scheduler dispatch is
  safe and preferable to losing a reminder window.
- `notification_worker` isolates failures per user: one user's malformed
  document logs an exception and the remaining users still get reminders.
- Gmail sync additionally enforces its own cooldown
  (`GMAIL_SYNC_COOLDOWN_SECONDS`, default 60s), so a scheduler that fires more
  often than the cooldown is throttled with `429 GMAIL_SYNC_RATE_LIMITED` rather
  than consuming the user's Gmail quota. See
  [`gmail-sync.md`](gmail-sync.md#rate-limiting).
- There is no retry-with-backoff worker. A failed sync is picked up by the next
  scheduled run; the manual **Sync now** button remains available.

## See also

- [`notification-preferences.md`](notification-preferences.md) — per-user
  preference gating that runs before any notification is created
- [`gmail-sync.md`](gmail-sync.md) — sync cursors, windows, and rate limiting
