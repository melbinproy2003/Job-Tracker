"""Gmail thread repository."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from google.cloud.firestore import Client

from app.integrations.firebase.firestore_client import get_firestore_client


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


class GmailThreadRepository:
    def __init__(self, client: Client | None = None):
        self._client = client

    @property
    def client(self) -> Client:
        if self._client is None:
            self._client = get_firestore_client()
        return self._client

    def _col(self, user_id: str):
        return self.client.collection("users").document(user_id).collection("gmail_threads")

    def upsert_by_gmail_id(
        self, user_id: str, gmail_thread_id: str, data: dict[str, Any]
    ) -> dict[str, Any]:
        existing = self.find_by_gmail_id(user_id, gmail_thread_id)
        if existing:
            # Preserve match associations
            preserved = {}
            for key in ("application_id", "match_status"):
                if existing.get(key) and key not in data:
                    preserved[key] = existing[key]
            return self.update(user_id, existing["id"], {**data, **preserved})
        return self.create(user_id, {**data, "gmail_thread_id": gmail_thread_id})

    def create(self, user_id: str, data: dict[str, Any]) -> dict[str, Any]:
        now = _utc_now()
        ref = self._col(user_id).document()
        payload = {**data, "id": ref.id, "user_id": user_id, "created_at": now, "updated_at": now}
        ref.set(payload)
        return payload

    def find_by_gmail_id(self, user_id: str, gmail_thread_id: str) -> dict[str, Any] | None:
        for item in self.list(user_id):
            if item.get("gmail_thread_id") == gmail_thread_id:
                return item
        return None

    def get(self, user_id: str, thread_id: str) -> dict[str, Any] | None:
        snap = self._col(user_id).document(thread_id).get()
        if not snap.exists:
            return None
        data = snap.to_dict() or {}
        data["id"] = snap.id
        return data

    def list(self, user_id: str, *, application_id: str | None = None) -> list[dict[str, Any]]:
        items = []
        for snap in self._col(user_id).stream():
            data = snap.to_dict() or {}
            data["id"] = snap.id
            if application_id and data.get("application_id") != application_id:
                continue
            items.append(data)
        items.sort(
            key=lambda x: x.get("last_message_at") or datetime.min.replace(tzinfo=timezone.utc),
            reverse=True,
        )
        return items

    def update(self, user_id: str, thread_id: str, data: dict[str, Any]) -> dict[str, Any]:
        payload = {**data, "updated_at": _utc_now()}
        ref = self._col(user_id).document(thread_id)
        ref.set(payload, merge=True)
        return self.get(user_id, thread_id) or {"id": thread_id, **payload}
