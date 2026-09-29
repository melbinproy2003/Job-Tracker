# Frontend Architecture

## Stack

- Flutter / Dart
- Riverpod (state)
- GoRouter (navigation)
- Dio (HTTP)
- Firebase Auth + FCM SDKs
- Drift + SQLite (local)
- Freezed + json_serializable (where useful)

## Folder layout

```
lib/
  app/           # MaterialApp, router, theme
  core/          # network, storage, firebase, notifications, shared utilities
  features/      # feature modules (clean architecture)
  shared/        # reusable UI primitives
```

## Feature module pattern

Every major feature follows:

```
feature/
  data/          # models, datasources, repository implementations
  domain/        # entities, repository contracts, usecases
  presentation/  # screens, widgets, controllers
  providers/     # Riverpod wiring
```

### Dependency rule

```
UI → Controller/Provider → UseCase → Repository → DataSource → API / SQLite
```

API calls never live inside widgets.

## Core responsibilities

| Module | Responsibility |
|--------|----------------|
| `core/network` | Dio client, endpoints, auth interceptor, errors |
| `core/storage` | Drift DB, tables, local repos, sync engine stub |
| `core/firebase` | App initialization |
| `core/notifications` | FCM registration + handlers |

## Gmail on Flutter

Flutter only calls FastAPI Gmail endpoints (`/gmail/connect`, `/sync`, `/threads`,
`/match`). It never holds Google client secrets or Gmail tokens.

## Offline

Repositories prefer local Drift reads. A `SyncEngine` placeholder prepares for
Phase 4 push/pull without implementing complex CRDT/conflict logic yet.
