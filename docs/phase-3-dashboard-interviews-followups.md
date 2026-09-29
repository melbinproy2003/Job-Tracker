# Phase 3 — Dashboard, Interviews & Follow-ups

## Scope

Adds post-application workflow features without Gmail, FCM, or calendar integrations.

- Dashboard aggregate API + Flutter home
- Interviews nested under applications
- Follow-ups (user-scoped collection)
- Application activity timeline
- Upcoming events (interviews + follow-ups)

## Firestore paths

```text
users/{userId}/applications/{applicationId}/interviews/{interviewId}
users/{userId}/applications/{applicationId}/activities/{activityId}
users/{userId}/followups/{followupId}
```

Existing Phase 2 paths are unchanged.

## API endpoints

| Method | Path | Notes |
|--------|------|--------|
| GET | `/api/v1/dashboard` | Single aggregate response |
| POST | `/api/v1/applications/{id}/interviews` | Create |
| GET | `/api/v1/applications/{id}/interviews` | List for application |
| GET | `/api/v1/interviews` | List / filter (`status`, `from`, `to`) |
| GET | `/api/v1/interviews/{id}` | Detail |
| PATCH | `/api/v1/interviews/{id}` | Update (`force` overrides conflict) |
| DELETE | `/api/v1/interviews/{id}` | Delete |
| POST | `/api/v1/followups` | Create (`force` overrides duplicate) |
| GET | `/api/v1/followups` | List / filter |
| GET | `/api/v1/followups/{id}` | Detail |
| PATCH | `/api/v1/followups/{id}` | Update |
| PATCH | `/api/v1/followups/{id}/complete` | Mark complete |
| DELETE | `/api/v1/followups/{id}` | Delete |
| GET | `/api/v1/applications/{id}/activities` | Activity timeline |

## Rules

- Identity always from verified Firebase UID
- Creating interviews/follow-ups does **not** auto-change application status
- Interview time conflicts warn (422 `INTERVIEW_CONFLICT`); client may retry with `force: true`
- Duplicate follow-ups warn (422 `FOLLOWUP_DUPLICATE`); client may retry with `force: true`
- Overdue follow-up: `completed == false` and `scheduled_at < now` (UTC)
- Timestamps stored UTC; Flutter displays local timezone

## Activity types (Phase 3)

`APPLICATION_CREATED`, `STATUS_CHANGED`, `INTERVIEW_CREATED`, `INTERVIEW_COMPLETED`, `FOLLOWUP_CREATED`, `FOLLOWUP_COMPLETED`, `APPLICATION_UPDATED`

Future (not implemented): `GMAIL_EMAIL_RECEIVED`, `GMAIL_EMAIL_SENT`
