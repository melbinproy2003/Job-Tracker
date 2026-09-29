# Job Tracker — Flutter Frontend

Feature-oriented Flutter app using Riverpod, GoRouter, Dio, Firebase, and Drift.

## Architecture

```
UI → Controller/Provider → UseCase → Repository → DataSource → API / Local DB
```

See [../../docs/frontend-architecture.md](../../docs/frontend-architecture.md).

## Setup

```bash
flutter pub get
flutter run
```

Firebase options (`firebase_options.dart`) are generated in Phase 1 with FlutterFire CLI.

## Notes

- Gmail OAuth secrets and refresh tokens never live in this app.
- FCM device tokens are registered via FastAPI, not stored in UI widgets.
- Offline SQLite (Drift) sync engine is scaffolded for Phase 4.
