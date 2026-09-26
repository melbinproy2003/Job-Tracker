# Development Roadmap

Phase numbering aligned with [`../BuildPlan.md`](../BuildPlan.md).

## Phase 1 — Foundations
- Project setup and structure
- Authentication (Firebase Auth + FastAPI verify)
- Flutter navigation (GoRouter)
- FastAPI base + Firebase Admin connection

## Phase 2 — Core entities
- Applications CRUD
- Companies
- Status management
- Status history (append-only)

## Phase 3 — Engagement
- Dashboard
- Interviews
- Follow-ups

## Phase 4 — Notifications
- In-app notification inbox
- FCM device registration and token rotation
- Push payload contract and deep-link routing
- Notification preferences

## Phase 5 — Gmail
- OAuth connect/callback
- Synchronization
- Email parsing
- Application matching + user confirmation

## Phase 6 — Offline
- Drift schemas
- Local repositories
- Sync architecture (push/pull)

## Phase 7 — Hardening
- Security review
- Performance
- Production preparation

## Status

Phases 1–5 are implemented, tested, and documented. Phase 6 has not started.
Phase 7 is partially done: tests and the security review are complete, but
emulator-tested Firestore rules, CI, and deployment configuration remain.

See [`../BuildPlan.md`](../BuildPlan.md) for the detailed checklist.
