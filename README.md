# Job Application Tracker

Personal, production-oriented mobile app for tracking job applications, interviews,
follow-ups, companies, resumes, and Gmail-related job communications.

## Architecture

```
Flutter  →  FastAPI REST API  →  Firebase Firestore
```

- **Auth:** Firebase Authentication (ID tokens verified by FastAPI)
- **Push:** Firebase Cloud Messaging
- **Email:** Gmail API via FastAPI only (no secrets on device)
- **Offline:** Drift + SQLite (sync engine planned for Phase 4)

See [docs/architecture.md](docs/architecture.md) for decisions and diagrams.

## Repository layout

```
job_application_tracker/
├── frontend/job_tracker/   # Flutter app (feature-oriented)
├── backend/                # Modular FastAPI application
├── docs/                   # Architecture & API docs
├── scripts/                # Dev helpers
├── README.md
├── LICENSE
└── .gitignore
```

## Quick start

### Backend

```bash
./scripts/setup_backend.sh
# edit backend/.env from backend/.env.example
./scripts/dev_backend.sh
```

API docs: http://localhost:8000/docs

### Frontend

```bash
cd frontend/job_tracker
flutter pub get
flutter run
```

Or: `./scripts/dev_frontend.sh`

## Current status

**Scaffold only.** Folder structure, placeholders, dependency manifests, route
stubs, schemas/models, and architecture docs are in place. Feature logic is
intentionally unimplemented — follow [docs/development-roadmap.md](docs/development-roadmap.md).

## Documentation

| Doc | Topic |
|-----|--------|
| [docs/architecture.md](docs/architecture.md) | System overview |
| [docs/frontend-architecture.md](docs/frontend-architecture.md) | Flutter layers |
| [docs/backend-architecture.md](docs/backend-architecture.md) | FastAPI modules |
| [docs/database-schema.md](docs/database-schema.md) | Firestore collections |
| [docs/api-specification.md](docs/api-specification.md) | REST endpoints |
| [docs/authentication.md](docs/authentication.md) | Firebase auth flow |
| [docs/gmail-integration.md](docs/gmail-integration.md) | Backend-only Gmail |
| [docs/notification-architecture.md](docs/notification-architecture.md) | FCM + in-app |
| [docs/offline-sync.md](docs/offline-sync.md) | Drift sync plan |
| [docs/security.md](docs/security.md) | Security rules |
| [docs/development-roadmap.md](docs/development-roadmap.md) | Phases 1–6 |

## Security highlights

- Never commit `.env` or service account keys
- Never expose Gmail tokens to Flutter
- Never auto-update application status from email alone
- Always scope data by verified Firebase `uid`

## License

MIT — see [LICENSE](LICENSE).
