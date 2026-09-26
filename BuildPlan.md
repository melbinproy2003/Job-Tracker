# Build Plan

Status of every phase, what is verified, and what remains manual.

> **Phase numbering note.** This plan and `docs/development-roadmap.md` do not
> agree. The roadmap calls Phase 4 "Offline" and Phase 6 "Hardening"; the
> working plan that produced this code treated Phase 4 as
> Notifications/FCM and Phase 5 as Gmail, with hardening folded in. This
> document follows the working plan. `docs/development-roadmap.md` should be
> renumbered to match.

## Summary

| Phase | Scope | Code | Tests | Docs | Manual config |
| --- | --- | --- | --- | --- | --- |
| 1 | Foundations + Auth | done | done | done | Firebase files |
| 2 | Applications, companies, status history | done | done | done | — |
| 3 | Dashboard, interviews, follow-ups | done | done | done | — |
| 4 | Notifications, FCM, device registration, preferences | done | done | done | Firebase + APNs |
| 5 | Gmail OAuth, sync, detection, matching, confirmation | done | done | done | Google OAuth client |
| 6 | Offline support (Drift, push/pull sync) | **not started** | — | stub | — |
| 7 | Hardening / production prep | partial (see below) | done | done | deployment |

## Verification

| Check | Command | Result |
| --- | --- | --- |
| Backend tests | `backend/.venv/bin/python -m pytest tests/ -q` | **46 passed, 1 warning** |
| Flutter tests | `flutter test` | **68 passed** |
| Static analysis | `flutter analyze` | 0 errors, 0 warnings, 10 pre-existing infos |
| Backend lint | `cd backend && ruff check app tests && ruff format --check app tests` | **clean** |
| Backend types | `cd backend && mypy app tests` | **clean** |
| Android build | `flutter build apk --debug` | **succeeds** |
| iOS build | — | not runnable on Linux |
| Firestore rules | `npm run test:rules` (emulator) | **32 passed** |
| Formatting | `dart format --output=none --set-exit-if-changed lib test` | clean |

The 10 remaining analyzer infos are all `deprecated_member_use` on
`DropdownButtonFormField.value` and one `curly_braces_in_flow_control_structures`,
all in Phase 1–3 files untouched by Phases 4/5.

## Phase 1 — Foundations and authentication
- [x] Project structure, FastAPI app, Firebase Admin connection
- [x] Google SSO via Firebase Auth, ID token verified server-side
- [x] GoRouter navigation with auth guard
- [x] Threadpool offload so token verification never blocks the event loop
- [ ] Firebase platform config files present on a real machine

## Phase 2 — Core entities
- [x] Applications CRUD, companies, status management
- [x] Append-only `status_history`; client writes denied in Firestore rules
- [x] Composite indexes for the dashboard queries

## Phase 3 — Engagement
- [x] Dashboard summary, interviews, follow-ups
- [x] Email-shaped forms and the upcoming-events view

## Phase 4 — Notifications and FCM
- [x] In-app inbox backed by the `notifications` collection
- [x] Device registration, token rotation, server-side deactivation
- [x] Push payload contract shared by backend and client
- [x] Deep-link routing (`NotificationRouter`) — pure and unit-tested
- [x] Foreground banner that never auto-navigates
- [x] Local notifications for data-only messages
- [x] Background isolate handler
- [x] User preferences honoured **before** a notification is created
- [x] Android config: permission, channel, icon, minSdk 24, desugaring, multidex
- [x] iOS `UIBackgroundModes: remote-notification`
- [ ] **Manual:** iOS Push Notifications capability + APNs key
- [ ] **Manual:** end-to-end FCM verification on a real device
  (see the checklist in [`docs/fcm-integration.md`](docs/fcm-integration.md))

Docs: [`notification-architecture.md`](docs/notification-architecture.md),
[`fcm-integration.md`](docs/fcm-integration.md),
[`notification-preferences.md`](docs/notification-preferences.md)

## Phase 5 — Gmail
- [x] OAuth connect/callback, signed single-use `state`, read-only scope
- [x] Refresh token encrypted at rest, never exposed to the client
- [x] Sync: history cursor, bounded 90-day query, 100-message cap, idempotent
- [x] Job-related detection with ordered category patterns
- [x] Application matching with explainable confidence scoring
- [x] Interview extraction (time, duration, meeting URL, interviewer)
- [x] **Suggestion-only pipeline** — three independent opt-ins on confirm
- [x] UI confidence gating: low-confidence matches start unselected
- [x] Routes, settings hub, application-detail Emails section
- [x] Per-user sync cooldowns: incremental (60s default,
      `GMAIL_SYNC_COOLDOWN_SECONDS`) and full-sync (300s default,
      `GMAIL_FULL_SYNC_COOLDOWN_SECONDS`). Over-eager clients get
      `429 GMAIL_SYNC_RATE_LIMITED` with `error.details.retry_after_seconds`,
      and the Flutter client shows the remaining wait instead of "try again".
- [ ] **Manual:** Google Cloud OAuth client + consent screen
- [ ] **Manual:** end-to-end connect → sync → confirm on a real device

Docs: [`gmail-integration.md`](docs/gmail-integration.md),
[`gmail-sync.md`](docs/gmail-sync.md),
[`email-matching.md`](docs/email-matching.md),
[`gmail-security.md`](docs/gmail-security.md)

### Known gaps
- **The sync rate limiter is per-process and in-memory.** Correct for the
  single-process deployment this project targets, but if the API is scaled to
  multiple instances each keeps its own window, so a user could still trigger
  roughly one sync per instance per cooldown. Move the timestamp onto the
  `gmail_accounts` document (it already carries `last_sync_at`) before scaling.
- Candidates come from the loaded application list, so a very old application
  outside the loaded page will not appear in the match picker.
- Sync failure surfaces as a generic error; there is no retry-with-backoff
  worker, only manual/periodic re-sync.

## Phase 6 — Offline (not started)
- [ ] Drift schemas and local database
- [ ] Read-through local repositories
- [ ] Push/pull sync architecture
- [ ] `firestore.rules` needs a new, tightly scoped client-write path —
  **not** a blanket `write`. See the Phase 7 note in `firestore.rules`.

## Phase 7 — Hardening (partial)
- [x] Unit tests for every implemented phase
- [x] Firestore rules reviewed for server-only writes
- [x] Security docs
- [x] Firestore rules exercised against the emulator: 32 tests in
      `tests/firestore.rules.test.js` (owner reads, cross-tenant isolation,
      server-only writes, audit-trail immutability, credential
      confidentiality, default deny)
- [x] Backend lint/typecheck wired into CI (`.github/workflows/ci.yml`:
      `ruff check`, `ruff format --check`, `mypy app tests`, `pytest`)
- [ ] End-to-end device testing
- [x] Deployment configuration for the reminder workers:
      [`docs/worker-deployment.md`](docs/worker-deployment.md) plus a cron-ready
      `scripts/run_reminders.sh` (verified end-to-end against the project)

## Not implemented, by decision
Deliberately out of scope for a single-user app. Each would add real
operational cost for no current benefit:

Kafka, RabbitMQ, Redis, Celery, Kubernetes, a separate notification
microservice, Gmail Pub/Sub push, and any client-side write path to Firestore.
