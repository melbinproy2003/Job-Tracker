# Database Schema (Firestore)

Firestore is the primary cloud database. Data is **user-scoped**.

## Collections

### `users/{userId}`
Profile document created on first `/auth/me`.

### `users/{userId}/companies/{companyId}`
| Field | Type | Notes |
|-------|------|-------|
| id | string | |
| user_id | string | owner |
| name | string | required |
| name_normalized | string | lowercase collapsed for duplicate detection |
| website | string? | |
| location | string? | |
| industry | string? | |
| notes | string? | |
| created_at | timestamp | UTC |
| updated_at | timestamp | UTC |

### `users/{userId}/applications/{applicationId}`
Central entity. Includes denormalized `company_name`.

Status values: `SAVED`, `APPLIED`, `VIEWED`, `SHORTLISTED`, `HR_CALL`, `TECHNICAL_ROUND`, `INTERVIEW`, `FINAL_ROUND`, `OFFER`, `ACCEPTED`, `REJECTED`, `WITHDRAWN`, `NO_RESPONSE`.

### `users/{userId}/applications/{applicationId}/status_history/{historyId}`
Append-only. Fields: `previous_status`, `new_status`, `changed_at`, `note`.

## Indexes

See `firestore.indexes.json` at repo root.

Suggested composite indexes (deploy when query volume grows):

- `applications`: `company_id` ASC + `applied_at` DESC
- `applications`: `status` ASC + `updated_at` DESC
- `applications`: `source` ASC + `created_at` DESC
- `applications`: `employment_type` ASC + `created_at` DESC
- `companies`: `name_normalized` ASC

Phase 2 list/search/filter currently loads the user's applications and filters/sorts/paginates in the API for simplicity (personal-scale). Indexes prepare for query push-down later.

## Security

Owner-only access via `firestore.rules` (`request.auth.uid == userId`). FastAPI remains the primary write path with Firebase ID token verification.
