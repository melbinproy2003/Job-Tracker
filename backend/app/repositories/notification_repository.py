"""In-app notification + preferences repository."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from google.cloud import firestore
from google.cloud.firestore import Client

from app.integrations.firebase.firestore_client import get_firestore_client


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


DEFAULT_PREFS = {
    "interview_reminders": True,
    "followup_reminders": True,
    "overdue_followups": True,
    "gmail_notifications": True,
    "application_suggestions": True,
}


class NotificationRepository:
    def __init__(self, client: Client | None = None):
        self._client = client

    @property
    def client(self) -> Client:
        if self._client is None:
            self._client = get_firestore_client()
        return self._client

    def _col(self, user_id: str):
        return self.client.collection("users").document(user_id).collection("notifications")

    def _prefs_ref(self, user_id: str):
        return (
            self.client.collection("users")
            .document(user_id)
            .collection("settings")
            .document("notifications")
        )

    def create(self, user_id: str, data: dict[str, Any]) -> dict[str, Any]:
        now = _utc_now()
        # Deterministic id when dedupe_key provided
        dedupe = data.pop("dedupe_key", None)
        ref = self._col(user_id).document(dedupe) if dedupe else self._col(user_id).document()
        if dedupe:
            existing = ref.get()
            if existing.exists:
                out = existing.to_dict() or {}
                out["id"] = ref.id
                out["_duplicate"] = True
                return out
        payload = {
            **data,
            "id": ref.id,
            "user_id": user_id,
            "read": False,
            "sent_at": data.get("sent_at") or now,
            "created_at": now,
        }
        if dedupe:
            payload["dedupe_key"] = dedupe
        ref.set(payload)
        return payload

    def get(self, user_id: str, notification_id: str) -> dict[str, Any] | None:
        snap = self._col(user_id).document(notification_id).get()
        if not snap.exists:
            return None
        data = snap.to_dict() or {}
        data["id"] = snap.id
        return data

    def list(self, user_id: str, *, limit: int = 50) -> list[dict[str, Any]]:
        """Newest-first notification inbox.

        Ordering and limiting are pushed down to Firestore so only `limit`
        documents are read; cost stays flat as history grows.
        """
        items: list[dict[str, Any]] = []
        query = (
            self._col(user_id)
            .order_by("created_at", direction=firestore.Query.DESCENDING)
            .limit(limit)
        )
        for snap in query.stream():
            data = snap.to_dict() or {}
            data["id"] = snap.id
            items.append(data)
        return items

    def unread_count(self, user_id: str) -> int:
        """Count unread rows in Firestore instead of scanning the inbox."""
        return sum(1 for _ in self._col(user_id).where("read", "==", False).stream())

    def mark_read(self, user_id: str, notification_id: str) -> dict[str, Any] | None:
        ref = self._col(user_id).document(notification_id)
        snap = ref.get()
        if not snap.exists:
            return None
        ref.set({"read": True}, merge=True)
        data = snap.to_dict() or {}
        data["id"] = snap.id
        data["read"] = True
        return data

    def mark_all_read(self, user_id: str) -> int:
        """Flip every unread notification using a single batched write."""
        refs = [snap.reference for snap in self._col(user_id).where("read", "==", False).stream()]
        if not refs:
            return 0
        batch = self.client.batch()
        for ref in refs:
            batch.set(ref, {"read": True}, merge=True)
        batch.commit()
        return len(refs)

    def delete(self, user_id: str, notification_id: str) -> bool:
        ref = self._col(user_id).document(notification_id)
        if not ref.get().exists:
            return False
        ref.delete()
        return True

    def get_preferences(self, user_id: str) -> dict[str, Any]:
        snap = self._prefs_ref(user_id).get()
        if not snap.exists:
            return dict(DEFAULT_PREFS)
        data = snap.to_dict() or {}
        return {**DEFAULT_PREFS, **data}

    def set_preferences(self, user_id: str, prefs: dict[str, Any]) -> dict[str, Any]:
        payload = {**DEFAULT_PREFS, **prefs, "updated_at": _utc_now()}
        self._prefs_ref(user_id).set(payload, merge=True)
        return {**DEFAULT_PREFS, **prefs}
