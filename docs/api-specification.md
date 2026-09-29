# API Specification

Base path: `/api/v1`  
Auth: `Authorization: Bearer <Firebase ID token>` unless noted.

All mutating and read endpoints enforce user isolation using the verified token.

## Authentication

| Method | Path | Description |
|--------|------|-------------|
| GET | `/auth/me` | Current user profile |

## Applications

| Method | Path | Description |
|--------|------|-------------|
| POST | `/applications` | Create application |
| GET | `/applications` | List applications |
| GET | `/applications/{id}` | Get application |
| PATCH | `/applications/{id}` | Update application fields |
| DELETE | `/applications/{id}` | Delete application |
| PATCH | `/applications/{id}/status` | Change status + append history |
| GET | `/applications/{id}/history` | Status history (append-only) |

`user_id` must **not** be accepted from request bodies.

## Companies

| Method | Path |
|--------|------|
| POST | `/companies` |
| GET | `/companies` |
| GET | `/companies/{id}` |
| PATCH | `/companies/{id}` |
| DELETE | `/companies/{id}` |

## Interviews

| Method | Path |
|--------|------|
| POST | `/interviews` |
| GET | `/interviews` |
| GET | `/interviews/{id}` |
| PATCH | `/interviews/{id}` |
| DELETE | `/interviews/{id}` |

## Follow-ups

| Method | Path |
|--------|------|
| POST | `/followups` |
| GET | `/followups` |
| PATCH | `/followups/{id}` |
| DELETE | `/followups/{id}` |

## Dashboard

| Method | Path |
|--------|------|
| GET | `/dashboard` | Aggregate counts and recent items |

## Gmail

| Method | Path | Description |
|--------|------|-------------|
| GET | `/gmail/connect` | Returns Google OAuth authorization URL |
| GET | `/gmail/callback` | OAuth redirect; stores encrypted refresh token |
| POST | `/gmail/sync` | Trigger sync |
| GET | `/gmail/threads` | List normalized threads |
| POST | `/gmail/match` | Propose/confirm application match & status suggestion |

Responses never include client secrets or OAuth tokens.

## Notifications

| Method | Path |
|--------|------|
| POST | `/notifications/device` | Register/refresh FCM token |
| GET | `/notifications` | List notifications |
| PATCH | `/notifications/{id}/read` | Mark read |

## Health

| Method | Path |
|--------|------|
| GET | `/health` | Liveness (no auth) |

## Status codes (conventions)

- `401` invalid/missing token
- `403` cross-user access attempt
- `404` missing resource for this user
- `422` validation error
- `501` placeholder / not implemented yet
