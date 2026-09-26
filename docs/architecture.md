# System Architecture

## Overview

Job Application Tracker is a personal, production-oriented system with a clear
separation of concerns:

```
Flutter (mobile)
    ↓  REST (Bearer Firebase ID token)
FastAPI (business logic)
    ↓
Firebase Firestore (primary cloud DB)
```

Supporting services:

| Concern | Technology | Why |
|--------|------------|-----|
| Auth | Firebase Authentication | Battle-tested identity; ID tokens verify on backend |
| Push | Firebase Cloud Messaging | Native mobile delivery without a custom push stack |
| Email | Gmail API via FastAPI | Keeps OAuth secrets and tokens off the device |
| Offline | Drift + SQLite | Usable without network; sync later to FastAPI |

## Design principles

1. **Single modular backend** — one FastAPI app with layered modules, not microservices.
2. **Feature-oriented Flutter** — each feature owns data/domain/presentation/providers.
3. **Server-derived identity** — `user_id` always comes from verified Firebase tokens.
4. **Suggestion, not automation** — Gmail parsing never silently changes application status.
5. **Offline-first readiness** — local SQLite is the UI source of truth; sync is additive.
6. **Secrets stay server-side** — Google client secret, refresh tokens, encryption keys.

## High-level data flow

```
User action (Flutter)
  → Riverpod provider / controller
  → Use case
  → Repository (local SQLite ± remote Dio)
  → FastAPI route
  → Service
  → Repository (Firestore)
  → Firestore collection
```

## What we deliberately avoid

Kubernetes, Docker Swarm, RabbitMQ, Kafka, Elasticsearch, Redis (unless later
required), and separate microservices. Background work uses simple worker
entrypoints inside the same codebase (`backend/app/workers/`).

## Related docs

- [frontend-architecture.md](frontend-architecture.md)
- [backend-architecture.md](backend-architecture.md)
- [database-schema.md](database-schema.md)
- [api-specification.md](api-specification.md)
- [gmail-integration.md](gmail-integration.md)
- [notification-architecture.md](notification-architecture.md)
- [offline-sync.md](offline-sync.md)
- [security.md](security.md)
- [development-roadmap.md](development-roadmap.md)
