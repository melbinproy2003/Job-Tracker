# Notification Preferences

Users control which notification categories reach them. Preferences are stored
per user and honoured by the backend, so a user who turns something off stays
unsubscribed even on a device they have not opened since.

## Model

`NotificationPreferences` (`backend/app/schemas/notification.py`):

| Field | Default | Effect when off |
| --- | --- | --- |
| `interview_reminders` | `true` | no `INTERVIEW_REMINDER` is created or pushed |
| `followup_reminders` | `true` | no `FOLLOWUP_REMINDER` |
| `overdue_followups` | `true` | no `FOLLOWUP_OVERDUE` |
| `gmail_notifications` | `true` | no `GMAIL_EMAIL_DETECTED` / status suggestions |
| `application_suggestions` | `true` | no `APPLICATION_STATUS_SUGGESTION` |

Every flag defaults to `true`. Missing or partial documents are merged over
`DEFAULT_PREFS` on read, so adding a new category later does not require a
migration and never silently disables an existing user's settings.

## API

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/api/v1/notifications/preferences` | always returns a complete object |
| `PUT` | `/api/v1/notifications/preferences` | **send the full object** |

> The `PUT` body is a complete `NotificationPreferences`, not a patch. Because
> every field defaults to `true`, a field you omit is written back as `true`
> rather than left alone — a partial body silently re-enables categories. The
> Flutter screen always submits the full set it loaded for exactly this reason.
> A future `PATCH` route would be the cleaner API for a partial update.

Stored in the `settings` collection as a preferences subdocument keyed by user
id. All reads and writes are owner-scoped server-side; the client cannot
address another user's preferences because it never supplies a user id.

## Enforcement

Preferences are read by the reminder workers and the Gmail sync service **before**
`create_and_push`. A disabled category is not merely muted on the device — the
notification is never created, so it does not appear in the inbox either. This
keeps a single source of truth: what the user sees in the inbox is exactly what
they are subscribed to.

## Client

`frontend/job_tracker/lib/features/notifications/presentation/screens/`

- `notification_preferences_screen.dart` — the toggle list.
- Reached from the dashboard notification bell → **Preferences**, and from the
  settings hub.

The screen keeps a local draft so toggling does not fire a request per tap. The
draft is committed on save and the cached provider is invalidated afterwards;
on a load error the previous committed values are restored rather than leaving
the UI showing unsaved state.

Toggles are independent of the FCM **permission**: preferences choose *what* is
sent, the OS permission decides *whether anything can be delivered at all*.
A user with notifications fully switched off but permission granted still
receives nothing, and permission is never re-requested as a result of
preference changes.
