"""User repository — Firestore access scoped by Firebase UID."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from google.cloud.firestore import Client

from app.integrations.firebase.firestore_client import get_firestore_client

USERS_COLLECTION = "users"


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


class UserRepository:
    """CRUD against Firestore `users/{uid}` documents."""

    def __init__(self, client: Client | None = None):
        self._client = client

    @property
    def client(self) -> Client:
        if self._client is None:
            self._client = get_firestore_client()
        return self._client

    def get_by_id(self, user_id: str) -> dict[str, Any] | None:
        snap = self.client.collection(USERS_COLLECTION).document(user_id).get()
        if not snap.exists:
            return None
        data = snap.to_dict() or {}
        data["id"] = snap.id
        return data

    def create(self, user_id: str, data: dict[str, Any]) -> dict[str, Any]:
        now = _utc_now()
        payload = {
            **data,
            "id": user_id,
            "created_at": now,
            "updated_at": now,
            "last_login_at": now,
        }
        self.client.collection(USERS_COLLECTION).document(user_id).set(payload)
        return payload

    def update(self, user_id: str, data: dict[str, Any]) -> dict[str, Any]:
        payload = {**data, "updated_at": _utc_now()}
        ref = self.client.collection(USERS_COLLECTION).document(user_id)
        ref.set(payload, merge=True)
        snap = ref.get()
        result = snap.to_dict() or {}
        result["id"] = user_id
        return result

    def list_all(self, *, limit: int = 1000) -> list[dict[str, Any]]:
        """Enumerate users for backend jobs.

        Used only by workers (reminders / Gmail sync) which run with the Admin
        SDK and have no request context. Never exposed via the API.
        """
        items: list[dict[str, Any]] = []
        for snap in self.client.collection(USERS_COLLECTION).limit(limit).stream():
            data = snap.to_dict() or {}
            data["id"] = snap.id
            items.append(data)
        return items

    def upsert_from_claims(self, user_id: str, profile: dict[str, Any]) -> dict[str, Any]:
        """Create user on first login; refresh profile + last_login_at thereafter."""
        existing = self.get_by_id(user_id)
        now = _utc_now()
        if existing is None:
            return self.create(
                user_id,
                {
                    "email": profile.get("email"),
                    "display_name": profile.get("display_name"),
                    "photo_url": profile.get("photo_url"),
                    "email_verified": bool(profile.get("email_verified", False)),
                },
            )

        updates = {
            "email": profile.get("email", existing.get("email")),
            "display_name": profile.get("display_name", existing.get("display_name")),
            "photo_url": profile.get("photo_url", existing.get("photo_url")),
            "email_verified": bool(
                profile.get("email_verified", existing.get("email_verified", False))
            ),
            "last_login_at": now,
        }
        return self.update(user_id, updates)
