# Local storage and sync — reserved for Phase 6

This folder is intentionally empty of implementation.

Offline support (Drift schemas, local repositories, and a push/pull sync
engine) is **Phase 6 and has not started**. The `database_tables/`,
`repositories/`, and `sync/` subfolders are placeholders.

The previous stub files (`local_database.dart`, `sync/sync_engine.dart`) were
removed rather than left in place. They threw `UnimplementedError`, were
imported by nothing, and would only have been a runtime trap: writing them
from scratch against the real Drift schema is less work than inheriting a
broken skeleton, and it avoids implying the feature exists.

Phase 6 also requires a new, tightly scoped client-write path in
`firestore.rules` — see the note in that file. Reintroducing a blanket
`allow write` would defeat the server-only-write guarantee the current rules
enforce.
