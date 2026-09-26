# Gmail Integration

## The one hard rule

> **Gmail access is backend-only. The app never holds a Gmail credential.**

Flutter never receives, stores, or transmits:

- the Google client secret
- a Gmail refresh token
- a Gmail access token

A refresh token is effectively a permanent, full read grant over the user's
mailbox. Putting one on a device — even encrypted — is the single worst thing
this feature could do. The app talks only to `FastAPI`, and FastAPI is the
only process that ever sees a token.

```
Flutter ──auth──▶ FastAPI ──service account──▶ Firebase
    │                 │
    │                 └──OAuth (backend)──▶ Google ──▶ Gmail API
    │                                              │ decrypt token
    │                                              ▼
    └──◀── normalized threads / suggestions ── detect → match → store
```

## Lifecycle

1. **Connect** — `GET /api/v1/gmail/connect` returns an authorization URL built
   by `GmailOAuthService`, with a signed, single-use `state` bound to the user.
2. **Authorize** — the user consents in the browser. Only
   `https://www.googleapis.com/auth/gmail.readonly` is requested.
3. **Callback** — `GET /api/v1/gmail/callback?code=…&state=…` verifies `state`,
   exchanges the code, and encrypts the refresh token into `gmail_accounts`.
4. **Redirect** — the browser is sent to `gmail_frontend_success_url`
   (`jobtracker://gmail/connected`), never back to a raw token-bearing URL.
5. **Sync** — `POST /api/v1/gmail/sync` pulls recent threads
   (see [`gmail-sync.md`](gmail-sync.md)).
6. **Detect & match** — see [`email-matching.md`](email-matching.md).
7. **Suggest** — a *suggestion* is stored against the application. Nothing is
   mutated yet.
8. **Confirm** — the user reviews and confirms
   (`POST /api/v1/gmail/matches/{thread_id}/confirm`).
9. **Disconnect** — `DELETE /api/v1/gmail/accounts/{id}` deletes the stored
   credential.

## API

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/api/v1/gmail/accounts` | connected accounts (never tokens) |
| `GET` | `/api/v1/gmail/connect` | authorization URL |
| `GET` | `/api/v1/gmail/callback` | OAuth redirect target |
| `POST` | `/api/v1/gmail/sync` | pull now; `full_sync` for history |
| `GET` | `/api/v1/gmail/threads` | list; optional `application_id` filter |
| `GET` | `/api/v1/gmail/threads/{id}` | one thread with match + interview suggestion |
| `GET` | `/api/v1/gmail/messages/{id}` | one normalized message |
| `POST` | `/api/v1/gmail/matches/{id}/confirm` | link, optionally apply status / create interview |
| `POST` | `/api/v1/gmail/matches/{id}/ignore` | dismiss the suggestion |
| `DELETE` | `/api/v1/gmail/accounts/{id}` | revoke and delete |

All routes require a Firebase ID token, and every repository call is scoped by
the authenticated user id taken from the token — never from the request body.
Thread ids from another user return `NotFoundError`, not someone else's data.

## The non-negotiable: nothing mutates itself

This is the central product rule of Phase 5.

> An email may **suggest**. Only the user may **act**.

`confirm_match` has three independent opt-ins, and each is off unless asked for:

| Field | Default | Effect |
| --- | --- | --- |
| `application_id` | *required* | links the thread and its messages |
| `confirm_status` | `null` | applies `suggested_status` |
| `create_interview` + `interview` | `false` / `null` | creates the interview |

A request with only `application_id` — which is exactly what the UI offers by
default — links the email and **changes nothing else**. This is pinned by
`test_confirm_links_without_mutating`, which asserts the status service and
interview service receive zero calls.

An interview request without `scheduled_at` is rejected with `ValidationError`
rather than creating a dateless interview
(`test_create_interview_without_a_schedule_is_rejected`).

Status changes still go through `ApplicationStatusService`, so `status_history`
and the activity log stay accurate and the change is attributable to the user,
not to a background job.

## Client

`frontend/job_tracker/lib/features/gmail/`

| Layer | Files |
| --- | --- |
| Data | `data/datasources/gmail_api_datasource.dart`, `data/models/gmail_thread_model.dart` |
| Domain | `domain/entities/gmail_thread.dart`, `domain/repositories/gmail_repository.dart` |
| Providers | `providers/gmail_providers.dart`, `gmail_providers.dart` (accounts) |
| Presentation | `presentation/screens/gmail_threads_screen.dart`, `gmail_thread_detail_screen.dart`, `gmail_message_detail_screen.dart`, `gmail_match_screen.dart`; `presentation/widgets/{gmail_connection_card,gmail_thread_card,application_match_card}.dart` |

Routes: `/gmail` (optionally `?applicationId=`), `/gmail/threads/{id}`,
`/gmail/threads/{id}/link`, `/gmail/messages/{id}`, and `/settings/email`.
Applications surface the feature through an **Emails** section that links to
`/gmail?applicationId=…` and flags unresolved matches.

### Confidence gating in the UI

`MatchConfidence` is bucketed in both runtimes — `veryHigh ≥ 90`, `high ≥ 70`,
`medium ≥ 40`, else `low` — and `isReliable` is `medium` and above.

`ApplicationMatchCard` pre-selects the best candidate **only when the
suggestion is reliable** (or the thread is already linked). A low-confidence
match starts with nothing selected and the "Link to application" button
disabled, so an uncertain match cannot be applied by reflex. The mutating
toggles ("Update status", "Add interview") are never pre-ticked at any
confidence.

Because the candidate list loads asynchronously, the card re-evaluates when
candidates first arrive — but never overwrites a choice the user has already
made.

## See also

- [`gmail-security.md`](gmail-security.md) — token storage, scopes, rules
- [`gmail-sync.md`](gmail-sync.md) — what gets pulled and stored
- [`email-matching.md`](email-matching.md) — detection and scoring
