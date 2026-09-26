# Job Application Tracker — Backend

Modular FastAPI application. Firestore is the primary database. Gmail OAuth
credentials and tokens stay server-side only.

## Quick start

```bash
../../scripts/setup_backend.sh
cp .env.example .env   # fill in secrets
../../scripts/dev_backend.sh
```

API docs: http://localhost:8000/docs

## Layout

See [../../docs/backend-architecture.md](../docs/backend-architecture.md).
