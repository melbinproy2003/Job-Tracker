# Resumes — reserved, not implemented

Resume upload and management. **Not part of Phases 1–5 and not started.**

Note that the backend does expose `GET /api/v1/resumes`, so the API surface
exists while the client does not consume it. Only the domain entity
(`Resume`), the repository interface, a placeholder screen, and an empty
provider are present. `ResumesScreen` is not routed and no provider is
watched.

The data layer that used to live here threw `UnimplementedError` and was
removed rather than left as a runtime trap.
