# Offline Sync Architecture

## Goal

The app should remain usable offline for browsing and editing applications.

## Target flow

```
UI
 → Riverpod
 → Repository
 → Local SQLite (Drift)
 → SyncEngine
 → FastAPI
 → Firestore
```

## Phase 4 approach (planned, not implemented yet)

1. Drift tables mirror core entities (`applications`, `companies`, …).
2. Local writes mark rows `pending_sync`.
3. `SyncEngine.pushPendingChanges()` sends mutations to FastAPI.
4. `SyncEngine.pullRemoteChanges()` applies remote updates.
5. Simple last-write-wins conflict policy initially (document clearly).

## Non-goals for now

- CRDTs
- Multi-device real-time collaboration
- Message queues

The `SyncEngine` class exists as a future-ready placeholder only.
