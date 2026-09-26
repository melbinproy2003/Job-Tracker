# Notification Architecture

Phase 4 delivers notifications through two channels that share one backend
source of truth: **Firebase Cloud Messaging** for delivery and a **`notifications`
Firestore collection** for the in-app inbox.

## Design rule

> The push is a *pointer*. The inbox is the *record*.

A push message is allowed to be lost (backgrounded app, revoked token, no
device at all). Nothing user-visible is ever stored only in FCM. Every
notification is written to Firestore **first**, and the push is derived from
that write. The FCM payload carries only an id and routing keys — never the
content the user needs to read.

```
Domain event (follow-up due, interview soon, Gmail match)
  → NotificationService.create_and_push()
      1. notifications.create()        ← durable, deduped, source of truth
      2. devices.list_active(user_id)  ← per-user registered tokens
      3. fcm.send() per token          ← best-effort delivery
      4. deactivate tokens FCM rejects
  → NotificationResponse
```

Because step 1 happens first, a user with no registered device still sees the
notification in the inbox. This is covered by
`test_notification_without_devices_is_still_persisted`.

## Event types

`NotificationType` (backend) / `AppNotificationType` (Flutter) — the two
enums must stay in step and are both asserted against the same string values.

| Value | Source | Related id |
| --- | --- | --- |
| `INTERVIEW_REMINDER` | `ReminderService` | `interview_id` |
| `FOLLOWUP_REMINDER` | `ReminderService` | `followup_id` |
| `FOLLOWUP_OVERDUE` | `ReminderService` | `followup_id` |
| `GMAIL_EMAIL_DETECTED` | `GmailSyncService` | `thread_id` |
| `APPLICATION_STATUS_SUGGESTION` | `GmailSyncService` | `thread_id` |
| `SYSTEM` | ad-hoc | — |

## Deduplication

`create_and_push` accepts a `dedupe_key`. A repeat with the same key returns
`None` and sends **no** push. The reminder workers derive keys from the
entity and window (e.g. `interview_{id}_24h`), so a worker that runs twice, or
a retry after a partial failure, cannot spam the user. This is what makes it
safe to schedule the workers frequently.

## Push payload contract

This is the contract between `push_data` in
`backend/app/services/notifications/notification_service.py` and
`NotificationPayloadKeys` in
`frontend/job_tracker/lib/core/notifications/notification_payload.dart`.

Every push data message always contains:

| Key | Source |
| --- | --- |
| `type` | `NotificationType` value |
| `notification_id` | the Firestore document id |
| `application_id` | `related_application_id`, if set |
| `interview_id` | `related_interview_id`, if set |
| `followup_id` | `related_followup_id`, if set |
| `title`, `body` | only for **data-only** messages |

Caller-supplied `data` is spread **before** the related ids, so a related id
always wins. Gmail adds `thread_id`, `gmail_message_id` and `suggested_status`.

> **Gotcha:** Gmail uses the short key `thread_id`, not `gmail_thread_id`.
> `gmail_thread_id` is the *Gmail API's* thread identifier and is stored on the
> thread document; the push key is the *Job Tracker* thread document id. Using
> the wrong one makes the deep link silently fall back to the notification hub.
> Both halves are pinned by tests:
> `test_gmail_push_uses_thread_id` (backend) and
> `NotificationRouter routes a Gmail push using the backend thread_id key`.

## Deep-link routing

`NotificationRouter` (`notification_router_core.dart`) is pure: payload in,
route out. It is deliberately separate from `NotificationHandler` so the
mapping is testable without a router, a `BuildContext`, or Firebase.

Resolution order (first match wins):

1. `gmail_message_id` → `/gmail/messages/{id}`
2. `thread_id` → `/gmail/threads/{id}`
3. `interview_id` → `/interviews/{id}?applicationId=…`, else `/interviews`
4. `followup_id` → `/applications/{app}?focusFollowupId=…`
5. `application_id` → `/applications/{id}`
6. otherwise → `/notifications`

Blank/whitespace ids are treated as absent, so a partially-populated payload
degrades to the hub instead of navigating to a broken detail page.

## Delivery semantics

- **Background / terminated** — the OS tray draws the notification. Tapping it
  cold-starts the app; `getInitialMessage` is handled before the first frame.
- **Foreground** — the OS stays silent and the app draws its own banner
  (`_ForegroundNotificationBanner` in `main_shell_screen.dart`).

Receiving a message **never** navigates. Navigation happens only on an
explicit tap, whether from the tray or the in-app banner, and both go through
`NotificationHandler.handleExternalPayload` so there is one code path. This is
asserted by `publishes a foreground payload without navigating`.

FCM sends display text in a separate `notification` block from the routing
keys in `data`. The handler merges the block's title/body into the published
payload (without overriding explicit data) because the banner renders nothing
when the title is empty.

## Components

| Concern | Location |
| --- | --- |
| Orchestration, dedupe, payload build | `backend/app/services/notifications/notification_service.py` |
| Per-device delivery, token cleanup | `backend/app/services/notifications/fcm_service.py` |
| Firebase Admin send | `backend/app/integrations/firebase/fcm_client.py` |
| Reminder generation | `backend/app/services/notifications/reminder_service.py` |
| Persistence | `backend/app/repositories/notification_repository.py` |
| Scheduled dispatch | `backend/app/workers/notification_worker.py`, `followup_worker.py` |
| HTTP surface | `backend/app/api/v1/notifications.py` |
| Client routing | `frontend/job_tracker/lib/core/notifications/notification_router_core.dart` |
| Client streams | `.../notification_handler.dart` |
| Local channel + tray payloads | `.../notification_service.dart` |
| Background isolate | `.../notification_background_handler.dart` |

## See also

- [`fcm-integration.md`](fcm-integration.md) — device registration and platforms
- [`notification-preferences.md`](notification-preferences.md) — user controls
- [`security.md`](security.md) — Firestore rules and token handling
