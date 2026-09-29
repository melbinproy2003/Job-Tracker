# Email Matching

How an email is judged to be job-related, which application it belongs to, and
how confident the system is allowed to be. See
[`gmail-integration.md`](gmail-integration.md) for the confirmation flow.

## Two separate questions

Matching is deliberately split, because conflating them is how such features
become noisy:

1. **Is this email job-related at all?** — `JobEmailDetector`. A binary gate.
2. **Which of my applications is it about?** — `ApplicationMatcher`. Produces
   scored candidates, and a suggestion is only stored if one scores high enough.

A thread can be job-related and still match nothing (a cold application
speculator, a job board notification). That is fine and is shown as
"unmatched" rather than being force-fit.

## 1. Job-related detection

`CATEGORY_PATTERNS` are ordered **most specific first** — `OFFER` before
`REJECTION` before `INTERVIEW` before `SHORTLIST` before
`APPLICATION_RECEIVED`. Order is significant: a rejection email that also
mentions "interview" must classify as a rejection, not an interview invite.

| Category | Suggested status | Example patterns |
| --- | --- | --- |
| `OFFER` | `OFFER` | "offer letter", "pleased to offer" |
| `REJECTION` | `REJECTED` | "unfortunately", "moved forward with other candidates" |
| `INTERVIEW` | `INTERVIEW` | "interview invitation", "schedule an interview" |
| `SHORTLIST` | `SHORTLISTED` | "shortlisted", "next round" |
| `APPLICATION_RECEIVED` | `APPLIED` | "application received", "thank you for applying" |

Separately, `JOB_HINTS` (`careers@`, `recruit`, `hiring`, `candidate`, …) is a
weak corroborating signal. Category patterns decide *what kind*; hints help
decide *whether at all* for mail with no clear category phrase.

Rejection and offer emails are the two patterns that make this feature worth
having, and they are also the two most expensive to get wrong — which is why a
detected status is only ever a **suggestion**.

## 2. Application matching

`ApplicationMatcher.find_candidates` scores every application the user owns and
returns those scoring above zero, sorted by confidence.

| Signal | Points | Rationale |
| --- | --- | --- |
| Thread already linked to this application | +100 | strongest possible signal — the same conversation |
| Sender domain matches the company | +40 | `careers@abc.com` → `abc` in "Acme Corp" |
| Company name appears in subject/body | +25 | direct evidence |
| Job title tokens overlap | +25 | loose token overlap, needs ≥ half the title's tokens |
| Sender is the known recruiter address | +20 | the user recorded this recruiter |

Score is clamped to 100. Each candidate carries its `reasons`, so a suggestion
is explainable rather than a bare number — the UI can show *why* it matched.

`extract_domain` / `company_name_from_domain` handle the common case where the
company name is a legal or brand variant of the mail domain.

### Confidence buckets

Identical in both runtimes, and asserted on both sides:

| Bucket | Range | Reliable? |
| --- | --- | --- |
| `veryHigh` | ≥ 90 | yes |
| `high` | ≥ 70 | yes |
| `medium` | ≥ 40 | yes |
| `low` | < 40 | **no** |
| `unknown` | no score | **no** |

## 3. Interview extraction

`_extract_interview_hints` pulls a structured suggestion from the email body:

- `type` — technical / HR / phone / final
- `title`
- `scheduled_at` — parsed from a date/time phrase
- `duration_minutes`
- `meeting_url` — a Zoom/Meet/Teams link
- `interviewer_name`

A suggestion is only **actionable** when it has a `scheduled_at`. A date-less
interview is shown as information but cannot be created, because a dateless
interview is worse than no interview. The backend enforces this too
(`ValidationError`), so the rule does not depend on the client.

## 4. Everything is a suggestion

The pipeline's only outputs are stored suggestions and a push. It never writes
to `applications.status` and never creates an interview.

Confirmation is three independent opt-ins — link, apply status, create
interview — each off by default. See the table in
[`gmail-integration.md`](gmail-integration.md) and
`tests/unit/test_phase4_5_contracts.py`.

The UI mirrors the backend's confidence model: a reliable match pre-selects its
best candidate for review, while a **low-confidence match starts unselected with
the link button disabled**, so an uncertain suggestion can never be applied by
reflex. Status and interview toggles are never pre-ticked at any confidence.

## Tuning notes

- Patterns are intentionally conservative. A missed email is cheap (the user
  can sync again); a wrong status change corrupts the user's pipeline.
- Adding a pattern to an existing category does not change the ordering
  consequences — keep categories ordered most-specific-first.
- Confidence weights are additive, so adding a signal shifts existing scores.
  After changing a weight, re-check that the boundary cases still land in the
  intended bucket.
