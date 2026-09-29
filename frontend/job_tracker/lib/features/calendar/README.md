# Calendar — reserved, not implemented

A calendar view of interviews and follow-ups. **Not part of Phases 1–5 and not
started.**

Only the domain entity (`CalendarEvent`), the repository interface, a
placeholder screen, and an empty provider exist. Nothing is routed to
`CalendarScreen` and no provider is watched anywhere, so this feature is
inert.

The data layer that used to live here threw `UnimplementedError` and was
removed. When this feature is built, follow the pattern already proven in
`features/applications` or `features/gmail`: a `*_api_datasource.dart` for
Dio calls and a `*_repository_impl.dart` that maps models to entities.
