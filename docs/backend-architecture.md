# Backend Architecture

## Stack

- Python + FastAPI
- Pydantic v2
- Firebase Admin SDK
- Firestore
- Google OAuth 2.0 + Gmail API
- Modular workers for scheduled tasks

## Layering

```
api/v1          # HTTP routes, thin handlers
schemas         # request/response DTOs (Pydantic)
services        # business logic
repositories    # Firestore access with user isolation
models          # domain + enums
integrations    # Firebase, Google, FCM clients
workers         # gmail sync, follow-ups, notifications
core            # config, security, logging, exceptions
```

## Why modular monolith

For a single developer, one FastAPI process with clear modules is easier to
test, deploy, and reason about than microservices. Workers are scripts/entrypoints
in the same package, not separate deployable services (yet).

## Auth boundary

`api/v1/dependencies.py` verifies Firebase ID tokens and injects `user_id`.
Services/repositories must never accept a client-supplied `user_id` as authority.

## Gmail boundary

All Gmail OAuth and API traffic is server-side. Encrypted refresh tokens live in
Firestore (`gmail_accounts`). Access tokens are short-lived and never returned to
Flutter.

## Workers

| Worker | Purpose |
|--------|---------|
| `gmail_sync_worker` | Periodic mailbox sync |
| `followup_worker` | Due follow-up reminders |
| `notification_worker` | Dispatch pending notifications |

Run via cron / Cloud Scheduler / simple loop later — not a message bus.
