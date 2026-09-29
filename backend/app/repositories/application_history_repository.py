"""Application status history repository (append-only)."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from google.cloud.firestore import Client

from app.integrations.firebase.firestore_client import get_firestore_client


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


class ApplicationHistoryRepository:
    def __init__(self, client: Client | None = None):
        self._client = client

    @property
    def client(self) -> Client:
        if self._client is None:
            self._client = get_firestore_client()
        return self._client

    def _col(self, user_id: str, application_id: str):
        return (
            self.client.collection("users")
            .document(user_id)
            .collection("applications")
            .document(application_id)
            .collection("status_history")
        )

    def append(
        self,
        user_id: str,
        application_id: str,
        *,
        previous_status: str | None,
        new_status: str,
        note: str | None = None,
    ) -> dict[str, Any]:
        ref = self._col(user_id, application_id).document()
        payload = {
            "id": ref.id,
            "application_id": application_id,
            "user_id": user_id,
            "previous_status": previous_status,
            "new_status": new_status,
            "note": note,
            "changed_at": _utc_now(),
        }
        ref.set(payload)
        return payload

    def list(self, user_id: str, application_id: str) -> list[dict[str, Any]]:
        items: list[dict[str, Any]] = []
        for snap in self._col(user_id, application_id).stream():
            data = snap.to_dict() or {}
            data["id"] = snap.id
            items.append(data)
        items.sort(
            key=lambda x: x.get("changed_at") or datetime.min.replace(tzinfo=timezone.utc),
            reverse=True,
        )
        return items

    def delete_all(self, user_id: str, application_id: str) -> None:
        for snap in self._col(user_id, application_id).stream():
            snap.reference.delete()
