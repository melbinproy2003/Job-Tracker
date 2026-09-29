# Phase 6 — Email → Application Intelligence

## Scope

Builds on Phase 5 Gmail sync. Adds explainable classification, ranked matching,
discovery drafts, interview extraction with a shared Python↔Flutter contract,
confirm/unlink/timeline APIs, idempotent confirm actions, and body retention.

**Not in this phase:** offline-first sync (deferred to Phase 7), paid AI models,
silent status/interview mutations, frontend access to Gmail tokens.

## Guarantees

| Rule | Enforcement |
|------|-------------|
| No silent status/interview changes | `GmailMatchConfirm` requires explicit `confirm_status` / `create_interview` |
| Interview conflicts never force | `force_interview` defaults false; UI re-confirms |
| Confirm is idempotent | `applied_actions` keys on thread (`link:`, `status:`, `interview:`) |
| Tokens stay backend-only | Flutter only sees sanitized account/thread payloads |
| Schedule contract | `interview_suggestion.scheduled_at` only — no `date_hint`/`time_hint` as primary |
| Retention | Ingest caps body 4000 / snippet 500; cleanup clears old bodies, keeps metadata |

## Classification

`JobEmailDetector` returns:

- `is_job_related`, `category`, `suggested_status`
- `confidence`, `matched_signals` (explainable)
- `interview_suggestion` when schedule can be parsed

Categories include offer, rejection, interview subtypes (technical, HR, manager,
coding test, system design, final), shortlisted, application received, etc.

## Matching & discovery

`ApplicationMatcher.find_candidates` ranks applications with scored reasons
(company/domain/title/recruiter/URL/location/date proximity).

When no candidates: `build_application_draft` pre-fills create-application fields
(`source: Gmail`). User must still confirm create + link.

## APIs (additive)

| Method | Path | Notes |
|--------|------|--------|
| POST | `/api/v1/gmail/matches/{id}/confirm` | Link + optional status/interview; `force_interview` |
| POST | `/api/v1/gmail/matches/{id}/ignore` | Mark ignored |
| POST | `/api/v1/gmail/matches/{id}/unlink` | Clear link only |
| GET | `/api/v1/gmail/applications/{id}/timeline` | Email events for application |
| POST | `/api/v1/gmail/retention/cleanup` | Clear old `body_text` |

Confirm response includes `applied`, `interview_created`, `already_applied`,
`interview_conflict`, `conflict_message`, `interview_id`.

Thread detail includes `detected_category`, `matched_signals`, `match_candidates`,
`application_draft`, `interview_suggestion`.

## Flutter

- Models aligned to Phase 6 interview + match contracts
- Match screen: conflict dialog → optional `force_interview`
- Match card: ranked reasons, category/signals, discovery draft preview
- Application detail: email timeline + linked threads
- Thread detail: unlink (does not revert status/interviews)

## Tests

- Backend: `tests/unit/test_phase6_email_intelligence.py` (+ Phase 4/5 regression)
- Flutter: `test/phase6_email_intelligence_test.dart`

## Manual verification

1. Connect Gmail (Phase 5) and sync a mailbox with interview / offer / rejection mail.
2. Open a suggested thread → confirm link only; verify status unchanged.
3. Confirm again with status + interview toggles; verify activity + interview created.
4. Re-confirm same payload → `already_applied` / no duplicate interview.
5. Force a calendar conflict → conflict dialog; confirm only after “Create anyway”.
6. Unlink thread → application still has prior status/interview.
7. Application detail shows email timeline entries.
