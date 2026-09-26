# Gmail Sync

How mail moves from the Gmail API into Firestore, and what is deliberately
*not* copied. See [`gmail-integration.md`](gmail-integration.md) for the
lifecycle and API surface.

## Pull model

There is no Gmail push (Pub/Sub) topic. The mailbox is polled:

- **on demand** — `POST /api/v1/gmail/sync` from the Gmail settings screen;
- **scheduled** — a worker / Cloud Scheduler job can call the same endpoint or
  `POST /api/v1/notifications/process-reminders`.

This is the right trade for a single-user app: it costs one API call per
interval, needs no extra Google infrastructure, and a missed poll is repaired by
the next one because sync is **idempotent**.

## Incremental vs full

`GmailSyncService.sync(user_id, full_sync=False)` uses a `sync_cursor` stored
on the account:

- **incremental** (default) — `get_history(cursor)`, which returns *changes*
  since that id. Much cheaper than a mailbox crawl, but only reaches history
  from the cursor onward. If history fails for any reason the service silently
  falls back to the query path rather than losing the sync.
- **full** — `list_message_ids` with a server-side query
  (`newer_than:90d (application OR interview OR offer OR careers OR recruiting OR hiring)`),
  then a full fetch per thread. Used after a long gap, on first connect, and on
  demand.

Both paths are bounded on purpose. The 90-day window and a 100-message cap per
sync mean an unbounded mailbox crawl can never happen — which would be slow,
expensive, and a privacy problem. Recent mail is what matters for job tracking.

The Gmail-side query does the first filtering, so newsletters and shopping mail
are never even fetched.

## Pipeline

```
Gmail API
  → EmailParser          strip quotes/forwarded blocks, normalise subject,
                         extract plain text, keep from/date/ids
  → JobEmailDetector     is this job-related? which category?
  → ApplicationMatcher   which of my applications? what confidence?
  → gmail_threads / gmail_messages   (upsert)
  → create_and_push(GMAIL_EMAIL_DETECTED | APPLICATION_STATUS_SUGGESTION)
```

### Normalisation

`EmailParser` removes `Re:`/`Fwd:` prefixes, signature blocks, and quoted
history so that matching is not skewed by an entire previous thread appended
to the newest message. `normalize_subject` and `normalize_email` lowercase and
strip display-name forms (`"A. Recruiter <Careers@ABC.com>"` →
`careers@abc.com`) so comparisons are stable.

### What is stored

| Collection | Contents |
| --- | --- |
| `gmail_accounts` | encrypted refresh token, account email, history id, scopes |
| `gmail_threads` | subject, snippet, is_job_related, category, match status, confidence, `suggested_application_id`, `suggested_status`, interview suggestion |
| `gmail_messages` | per-message ids, thread id, from, date, normalized text |

Raw Gmail API JSON is **not** stored, and neither is the access token — only
the encrypted refresh token on the account.

## Idempotency

Upserts key on stable ids, so a repeated poll updates rather than duplicates:

- thread → Gmail `threadId`
- message → Gmail `id`
- notification → `dedupe_key` (see
  [`notification-architecture.md`](notification-architecture.md))

The practical effect: polling twice in a row sends exactly one push. Without
the dedupe key this feature would spam the user on every poll.

Only *changes* produce notifications. A full sync that re-reads already-seen
threads must not re-notify; this is what the dedupe key and the stored ids
guarantee.

## Non-job mail

Anything the detector does not flag as job-related is **skipped entirely** — no
`gmail_threads` document, no notification. Personal mail, newsletters and
shopping receipts are not retained, which keeps the store small and the privacy
story simple: *Job Tracker only keeps the job-related mail it matched you on.*

A full sync therefore does not create a searchable copy of the mailbox.

## Push payload

A job-related email that produces a suggestion pushes:

```python
data = {
    "thread_id": thread["id"],          # Job Tracker thread doc id
    "gmail_message_id": message_id,
    "suggested_status": suggested_status,  # when detected
}
```

Note the short `thread_id` key — see the contract note in
[`notification-architecture.md`](notification-architecture.md). Tapping the push
routes to `/gmail/threads/{thread_id}`.

## Failure handling

| Failure | Behaviour |
| --- | --- |
| No account connected | `NotFoundError` / `GMAIL_NOT_CONNECTED` — an explicit error, not a silent no-op, so the UI can prompt to connect |
| Refresh token revoked or expired | `GmailOAuthService` raises "Gmail authorization expired. Please reconnect Gmail." The UI surfaces this as a reconnect prompt |
| History call fails | falls back to the bounded query path, so the sync still completes |
| Gmail 4xx rate limit | surfaced as an error; the next poll retries — sync is idempotent so a retry is safe |
| Partial failure mid-thread | thread upserts already committed stand; the next poll completes the rest |
| Concurrent sync for the same user | rejected with `409 GMAIL_SYNC_IN_PROGRESS` by an in-process lock, so a double-tap cannot run two syncs |

Already-seen messages are skipped via `find_by_gmail_id` before any API fetch,
so a repeated poll costs no Gmail reads for already-known mail.

## Cost control

- history-based incremental sync by default;
- bounded full-sync window;
- a push only on *new or changed* job-related mail;
- messages already known are skipped before the API fetch;
- a per-user in-process lock rejects concurrent syncs;
- a failed sync is safe to retry, because upserts and dedupe keys make it
  idempotent rather than duplicating.

### Known gap: no rate limiting

`POST /api/v1/gmail/sync` is **not** rate limited. An authenticated client
could call it in a loop and consume Gmail API quota, which for a `gmail.readonly`
user can also count against their own account's 403. The sync is idempotent, so
this cannot corrupt data — it is a cost and courtesy problem, not a correctness
one. Add a per-user limiter (e.g. `slowapi`, or a timestamp on
`gmail_accounts.last_sync_at`) before exposing the endpoint outside a
single-user deployment.

## See also

- [`email-matching.md`](email-matching.md)
- [`gmail-security.md`](gmail-security.md)
