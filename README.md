# Job Application Tracker

Personal, production-oriented mobile app for tracking job applications, interviews,
follow-ups, companies, resumes, and Gmail-related job communications.

## Current status

**Phases 1–5 complete (code, tests, and docs).** Phases 1–3 cover
foundations, core entities, and engagement; Phase 4 adds notifications, FCM, and
preferences; Phase 5 adds Gmail email intelligence with mandatory user
confirmation. Phase 6 (offline) has not started.

Verified: 38 backend tests, 63 Flutter tests, clean `flutter analyze`, and a
successful `flutter build apk --debug`.

Firebase/Google credentials and the iOS Push Notifications capability must be
configured before end-to-end device testing — see
[BuildPlan.md](BuildPlan.md) for exactly what remains manual.

## Architecture

```
Google Account → Google Sign-In → Firebase Auth → Firebase ID Token
    → Flutter (Dio) → FastAPI → Firebase Admin verify_id_token → Firestore users/{uid}
```

- **Auth:** Google SSO only (no password login)
- **Push:** FCM + in-app inbox, backend-orchestrated
- **Gmail:** backend-only OAuth with read-only scope; tokens are encrypted and
  never reach the device
- **Offline:** Phase 6, not started

## Phase 4 & 5 API

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/v1/notifications` | Inbox |
| GET | `/api/v1/notifications/unread-count` | Badge count |
| PATCH | `/api/v1/notifications/{id}/read` | Mark read |
| PATCH | `/api/v1/notifications/read-all` | Mark all read |
| DELETE | `/api/v1/notifications/{id}` | Delete |
| GET/PUT | `/api/v1/notifications/preferences` | Preferences |
| POST | `/api/v1/notifications/devices` | Register FCM token |
| DELETE | `/api/v1/notifications/devices/{id}` | Unregister device |
| GET | `/api/v1/gmail/accounts` | Connected accounts |
| GET | `/api/v1/gmail/connect` | Start OAuth |
| GET | `/api/v1/gmail/callback` | OAuth redirect |
| POST | `/api/v1/gmail/sync` | Pull mail |
| GET | `/api/v1/gmail/threads` | List threads |
| GET | `/api/v1/gmail/threads/{id}` | Thread detail |
| GET | `/api/v1/gmail/messages/{id}` | Message detail |
| POST | `/api/v1/gmail/matches/{id}/confirm` | Confirm match |
| POST | `/api/v1/gmail/matches/{id}/ignore` | Dismiss suggestion |
| DELETE | `/api/v1/gmail/accounts/{id}` | Disconnect |

All require a Bearer Firebase ID token.

See [docs/architecture.md](docs/architecture.md) and [docs/authentication.md](docs/authentication.md).

## Repository layout

```
Job-Tracker/
├── frontend/job_tracker/   # Flutter app
├── backend/                # FastAPI
├── docs/
├── scripts/
├── firestore.rules
├── README.md
├── LICENSE
└── .gitignore
```

## Frontend env (`.env`)

```bash
cd frontend/job_tracker
cp .env.example .env
# edit API_BASE_URL and GOOGLE_SERVER_CLIENT_ID
flutter pub get
flutter run
```

No need for `--dart-define` in normal local development.

## Quick start

### Backend

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env        # fill FIREBASE_* values
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

- Health: http://localhost:8000/health
- Auth health: http://localhost:8000/api/v1/auth/health
- Docs: http://localhost:8000/docs

### Frontend

1. Complete [Firebase setup](docs/phase-1-firebase-setup.md)
2. Copy and edit env: `cp .env.example .env`
3. Run:

```bash
cd frontend/job_tracker
flutter pub get
flutter run
```

Optional overrides (CI): `--dart-define=API_BASE_URL=...` still works and wins over `.env`.

## Phase 1 API

| Method | Path | Auth |
|--------|------|------|
| GET | `/api/v1/auth/health` | No |
| GET | `/api/v1/auth/me` | Bearer Firebase ID token |

## Documentation

| Doc | Topic |
|-----|--------|
| [docs/phase-1-firebase-setup.md](docs/phase-1-firebase-setup.md) | Firebase + Google Sign-In setup |
| [docs/authentication.md](docs/authentication.md) | Auth architecture |
| [docs/security.md](docs/security.md) | Security rules |
| [BuildPlan.md](BuildPlan.md) | Phase status, verification, remaining work |
| [docs/development-roadmap.md](docs/development-roadmap.md) | Phases |
| [docs/notification-architecture.md](docs/notification-architecture.md) | Push + inbox design, payload contract |
| [docs/fcm-integration.md](docs/fcm-integration.md) | Device registration, platforms, permissions |
| [docs/notification-preferences.md](docs/notification-preferences.md) | Per-category controls |
| [docs/gmail-integration.md](docs/gmail-integration.md) | OAuth lifecycle, confirmation model |
| [docs/gmail-sync.md](docs/gmail-sync.md) | Sync pipeline, idempotency, cost |
| [docs/email-matching.md](docs/email-matching.md) | Detection and confidence scoring |
| [docs/gmail-security.md](docs/gmail-security.md) | Threat model and controls |

## License

MIT — see [LICENSE](LICENSE).
