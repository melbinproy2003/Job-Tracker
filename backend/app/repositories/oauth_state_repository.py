"""Short-lived OAuth state storage (global ``_oauth_states`` collection).

Holds CSRF ``state`` → user binding plus the PKCE ``code_verifier`` for the
same authorization request. Documents are deleted on consume (single-use).
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from google.cloud.firestore import Client

from app.integrations.firebase.firestore_client import get_firestore_client


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


@dataclass(frozen=True)
class PendingOAuthState:
    user_id: str
    code_verifier: str


class OAuthStateRepository:
    """Stores OAuth CSRF state → user_id + PKCE verifier temporarily."""

    def __init__(self, client: Client | None = None):
        self._client = client

    @property
    def client(self) -> Client:
        if self._client is None:
            self._client = get_firestore_client()
        return self._client

    def _col(self):
        return self.client.collection("_oauth_states")

    def save(
        self,
        state: str,
        user_id: str,
        *,
        code_verifier: str,
        ttl_minutes: int = 15,
    ) -> None:
        if not code_verifier:
            raise ValueError("code_verifier is required when saving OAuth state")
        self._col().document(state).set(
            {
                "user_id": user_id,
                "code_verifier": code_verifier,
                "created_at": _utc_now(),
                "expires_at": _utc_now() + timedelta(minutes=ttl_minutes),
                "used": False,
            }
        )

    def consume(self, state: str) -> PendingOAuthState | None:
        """Atomically read-and-delete a pending state.

        Returns None for missing, expired, already-used, or incomplete records
        (including missing ``code_verifier``).
        """
        ref = self._col().document(state)
        snap = ref.get()
        if not snap.exists:
            return None
        data = snap.to_dict() or {}
        # Single-use: delete before validating so a concurrent retry cannot reuse.
        ref.delete()

        if data.get("used"):
            return None
        expires = data.get("expires_at")
        if isinstance(expires, datetime):
            exp_utc = expires if expires.tzinfo else expires.replace(tzinfo=timezone.utc)
            if exp_utc < _utc_now():
                return None
        user_id = data.get("user_id")
        code_verifier = data.get("code_verifier")
        if not user_id or not code_verifier:
            return None
        return PendingOAuthState(user_id=str(user_id), code_verifier=str(code_verifier))
