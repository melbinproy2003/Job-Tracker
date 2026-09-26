# Authentication (Phase 1)

## Method

**Google SSO only** via:

```
Google Sign-In → Firebase Auth → Firebase ID Token → FastAPI → verify_id_token → users/{uid}
```

No email/password, phone, anonymous, or other social providers.

## Flutter

- `FirebaseAuthDataSource` performs Google + Firebase credential exchange
- `AuthApiDataSource` calls `GET /api/v1/auth/me`
- `AuthController` owns a single `AuthenticationState`
- GoRouter redirects based on that state (`/auth/login` ↔ `/home`)
- Dio `AuthInterceptor` attaches `Authorization: Bearer <firebase_id_token>`

## FastAPI

- `FirebaseTokenVerifier` verifies ID tokens (never logs them)
- `get_current_user` dependency upserts `users/{uid}` in Firestore
- UID always comes from verified claims — never from request bodies

## Endpoints

| Method | Path | Auth |
|--------|------|------|
| GET | `/api/v1/auth/health` | No |
| GET | `/api/v1/auth/me` | Bearer Firebase ID token |

## Setup

See [phase-1-firebase-setup.md](phase-1-firebase-setup.md).
