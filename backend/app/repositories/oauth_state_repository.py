"""Short-lived OAuth state storage (users/{uid} not required — global collection)."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from google.cloud.firestore import Client

from app.integrations.firebase.firestore_client import get_firestore_client


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


class OAuthStateRepository:
    """Stores OAuth CSRF state → user_id mapping temporarily."""

    def __init__(self, client: Client | None = None):
        self._client = client

    @property
    def client(self) -> Client:
        if self._client is None:
            self._client = get_firestore_client()
        return self._client

    def _col(self):
        return self.client.collection("_oauth_states")

    def save(self, state: str, user_id: str, ttl_minutes: int = 15) -> None:
        self._col().document(state).set(
            {
                "user_id": user_id,
                "created_at": _utc_now(),
                "expires_at": _utc_now() + timedelta(minutes=ttl_minutes),
            }
        )

    def consume(self, state: str) -> str | None:
        ref = self._col().document(state)
        snap = ref.get()
        if not snap.exists:
            return None
        data = snap.to_dict() or {}
        ref.delete()
        expires = data.get("expires_at")
        if expires and expires < _utc_now():
            return None
        return data.get("user_id")
