# Gmail Security

Threat model and controls for the Phase 5 Gmail integration. See
[`gmail-integration.md`](gmail-integration.md) for the feature and
[`../firestore.rules`](../firestore.rules) for the enforceable rules.

## Asset

A Gmail **refresh token** is a standing, revocable grant of read access to the
user's entire mailbox. It does not expire on its own and survives password
changes. It is the highest-value secret in this project — more sensitive than
the Firebase ID token (which is short-lived) and far more sensitive than any
user data the app stores.

Everything below follows from one requirement: **that token must never exist
anywhere the user or an attacker can read it, except encrypted in Firestore,
reachable only by the backend.**

## Controls

### 1. Credentials never reach the client

- The Google client secret lives only in backend env.
- The OAuth code exchange happens in FastAPI.
- The refresh token is written straight to `gmail_accounts`, encrypted.
- `GmailAccountResponse` has no field that can carry a token; the account
  response exposes the account email and connection status only.
- Flutter has no code path that receives, stores, or transmits a Gmail token —
  `gmail_connection_card.dart` states this in the UI.

### 2. Encrypted at rest

`backend/app/utils/encryption.py` uses **Fernet (AES-128-CBC + HMAC-SHA256)**
from `cryptography`:

- accepts a raw 44-char Fernet key, otherwise derives one via
  `SHA-256(GMAIL_TOKEN_ENCRYPTION_KEY)`;
- `ENCRYPTION_KEY` is the fallback so a single secret is not required;
- a wrong key fails closed — `InvalidToken` becomes `EncryptionError` rather
  than returning garbage plaintext.

Key management is operational, not code: `GMAIL_TOKEN_ENCRYPTION_KEY` comes from
the deployment secret store, never from the repo, and **rotating it
invalidates every stored token** — users must reconnect Gmail. There is no
re-encryption migration, so schedule rotation deliberately.

### 3. Minimum scope

`GMAIL_SCOPES` requests exactly one scope:

```
https://www.googleapis.com/auth/gmail.readonly
```

Not `gmail.modify` — the app never sends, labels, archives, or deletes mail.
Not `mail.read` — `readonly` is all that is needed. A read-only grant means a
leak of the refresh token is a privacy incident, not a mailbox-integrity one.

### 4. Firestore rules deny the credential outright

```rules
match /gmail_accounts/{accountId} {
  allow read, write: if false;
}
```

`gmail_threads` and `gmail_messages` are also client-denied, so email content
is only ever served through the API. `_oauth_states` is denied for the same
reason as the credential and with the same force: a client that could read or
forge OAuth `state` could hijack the Gmail connect flow and bind the attacker's
Google account to the victim.

The catch-all `match /{document=**} { allow read, write: if false; }` means
anything not explicitly granted is denied — new collections fail closed rather
than open.

### 5. Every query is user-scoped

No repository call trusts a user id from the request. The id comes from the
verified Firebase ID token and is threaded through every query. A thread id
belonging to another user returns `NotFoundError` — never a partial result that
would leak existence.

`test_confirm_does_not_leak_across_users` covers the confirm path.

### 6. Server-only writes

Client writes are denied across all domain data, so invariants enforced in
FastAPI cannot be bypassed from a tampered client. Concretely, a client cannot:

- change an application status without the corresponding `status_history` and
  activity records;
- edit or delete the append-only `status_history` audit trail;
- write arbitrary fields onto its own profile;
- fabricate a notification or a device token.

The Admin SDK bypasses these rules by design, which is what makes "FastAPI is
the only write path" enforceable rather than aspirational.

### 7. OAuth `state` is signed and single-use

The authorization URL carries a state parameter bound to the user and
consumed on callback. Without it, an attacker could feed their own Google
authorization code into a victim's session and read the victim's synced mail.

### 8. No secrets in logs

- Tokens are never logged. `GmailAccountResponse` is built from sanitized
  fields, so even a whole-object log cannot leak one.
- Email content is sanitized before persistence — headers, signatures and
  quoted history are stripped by `EmailParser`.
- Only job-related mail is retained at all, so a Firestore dump does not
  become a mailbox archive.
- Error responses are truncated (`str(exc)[:120]`) and surfaced as
  `{"code", "message"}`, so internal detail does not leak to a client.

### 9. Disconnect really deletes

`DELETE /api/v1/gmail/accounts/{id}` removes the stored credential, so
disconnecting in the UI revokes the app's access rather than merely hiding it.
Recommend revoking the grant in the Google account as well.

## Client-side storage

| Item | Storage | Why |
| --- | --- | --- |
| FCM token | memory; backend is source of truth | not a secret, and a stale local copy would cause duplicate registration |
| Notification-permission "asked" flag | `flutter_secure_storage` | not secret, but must survive reinstall-adjacent state without a plain pref on a shared device |
| Firebase session | Firebase Auth SDK default | standard, short-lived |
| Gmail tokens | **nowhere** | backend only |

## Backend authentication boundary

- Clients authenticate with a Firebase **ID token**; it is short-lived (~1h)
  and verified server-side.
- The backend uses a **service account** to reach Firestore, so the Admin SDK
  is the only thing with write access.
- Blocking verification is executed in a threadpool rather than on the event
  loop, so a slow identity request cannot stall unrelated requests.
- Notification and Gmail routes are declared as sync `def` handlers; FastAPI
  runs them in a threadpool, which is the correct shape for blocking Firestore
  and HTTP work.

## What a compromise would look like

| Compromise | Exposure | Containment |
| --- | --- | --- |
| Stolen Firestore dump | encrypted tokens, unusable without the key | Fernet key lives only in the deployment secret store |
| Stolen backend env | full Gmail read | scope is read-only; rotate the Google client secret and the encryption key; every stored token becomes garbage |
| Tampered Flutter client | can send arbitrary requests | rules block all client writes; validation and business rules are server-side; it can only act as the legitimate user on their own data |
| Malicious Firestore write via Admin SDK | would require backend compromise | outside the client threat model; `status_history` and `activities` give an audit trail |

## Manual checklist before production

- [ ] `GMAIL_TOKEN_ENCRYPTION_KEY` is a real secret in the deployment store,
      not in `.env` committed to git, and not the app's other key.
- [ ] `GOOGLE_CLIENT_SECRET` is backend-only.
- [ ] `firestore.rules` deployed to the live project (not just the emulator).
- [ ] `firestore.indexes.json` deployed — the rules deny client writes, so
      index changes are a backend deploy.
- [ ] OAuth consent screen is **internal/testing** unless the app is public.
- [ ] Redirect URI in the Google console exactly matches
      `GOOGLE_REDIRECT_URI`.
- [ ] Firebase web/Android/iOS config files are **not** committed; the Google
      client id may be, the secret may not.
- [ ] Rotate the Google client secret before a public release.

## Known limitations

- Rotating the encryption key logs every user out of Gmail (no re-encryption
  migration exists).
- The OAuth `state` lifetime is short-lived; a callback arriving after expiry
  fails rather than being replayed.
- Read-only scope means the app cannot archive or label mail on the user's
  behalf — by design.
