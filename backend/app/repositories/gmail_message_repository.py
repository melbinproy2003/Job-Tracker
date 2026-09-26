"""Gmail message repository."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from google.cloud.firestore import Client

from app.integrations.firebase.firestore_client import get_firestore_client


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


class GmailMessageRepository:
    def __init__(self, client: Client | None = None):
        self._client = client

    @property
    def client(self) -> Client:
        if self._client is None:
            self._client = get_firestore_client()
        return self._client

    def _col(self, user_id: str):
        return self.client.collection("users").document(user_id).collection("gmail_messages")

    def find_by_gmail_id(self, user_id: str, gmail_message_id: str) -> dict[str, Any] | None:
        for item in self.list(user_id, limit=5000):
            if item.get("gmail_message_id") == gmail_message_id:
                return item
        return None

    def create_if_absent(
        self, user_id: str, gmail_message_id: str, data: dict[str, Any]
    ) -> tuple[dict[str, Any], bool]:
        existing = self.find_by_gmail_id(user_id, gmail_message_id)
        if existing:
            return existing, False
        now = _utc_now()
        ref = self._col(user_id).document()
        payload = {
            **data,
            "id": ref.id,
            "user_id": user_id,
            "gmail_message_id": gmail_message_id,
            "created_at": now,
            "updated_at": now,
        }
        ref.set(payload)
        return payload, True

    def get(self, user_id: str, message_id: str) -> dict[str, Any] | None:
        snap = self._col(user_id).document(message_id).get()
        if not snap.exists:
            return None
        data = snap.to_dict() or {}
        data["id"] = snap.id
        return data

    def list(
        self,
        user_id: str,
        *,
        thread_id: str | None = None,
        application_id: str | None = None,
        limit: int = 100,
    ) -> list[dict[str, Any]]:
        items = []
        for snap in self._col(user_id).stream():
            data = snap.to_dict() or {}
            data["id"] = snap.id
            if (
                thread_id
                and data.get("gmail_thread_id") != thread_id
                and data.get("thread_doc_id") != thread_id
            ):
                continue
            if application_id and data.get("application_id") != application_id:
                continue
            items.append(data)
        items.sort(
            key=lambda x: x.get("received_at") or datetime.min.replace(tzinfo=timezone.utc),
            reverse=True,
        )
        return items[:limit]

    def update(self, user_id: str, message_id: str, data: dict[str, Any]) -> dict[str, Any]:
        payload = {**data, "updated_at": _utc_now()}
        ref = self._col(user_id).document(message_id)
        ref.set(payload, merge=True)
        return self.get(user_id, message_id) or {"id": message_id, **payload}
