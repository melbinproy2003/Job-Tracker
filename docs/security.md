# Security

## Requirements checklist

1. Firebase ID tokens verified by FastAPI.
2. Never trust `user_id` from request bodies.
3. Always derive identity from authenticated Firebase token.
4. Gmail credentials never exposed to Flutter.
5. Never commit secrets to Git (`.env` gitignored; use `.env.example`).
6. Backend secrets via environment variables.
7. Validate every API request with Pydantic schemas.
8. Enforce user-level data isolation in repositories.
9. Users only access their own applications and related entities.
10. Sanitize/validate Gmail-derived data.
11. Do not auto-modify application status from email parsing alone.
12. Log security failures without logging OAuth tokens.

## Storage of secrets

| Secret | Location |
|--------|----------|
| Firebase private key | backend env |
| Google client secret | backend env |
| Gmail refresh tokens | Firestore encrypted field |
| ENCRYPTION_KEY | backend env |

## Logging

Log: event type, user_id (if known), error class.  
Do not log: Bearer tokens, OAuth codes, refresh/access tokens, encryption keys.
