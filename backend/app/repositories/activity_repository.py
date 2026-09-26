"""Application activity repository."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from google.cloud.firestore import Client

from app.integrations.firebase.firestore_client import get_firestore_client


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


class ActivityRepository:
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
            .collection("activities")
        )

    def create(self, user_id: str, application_id: str, data: dict[str, Any]) -> dict[str, Any]:
        now = _utc_now()
        ref = self._col(user_id, application_id).document()
        payload = {
            **data,
            "id": ref.id,
            "user_id": user_id,
            "application_id": application_id,
            "created_at": data.get("created_at") or now,
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
            key=lambda x: x.get("created_at") or datetime.min.replace(tzinfo=timezone.utc),
            reverse=True,
        )
        return items

    def delete_all_for_application(self, user_id: str, application_id: str) -> None:
        for snap in self._col(user_id, application_id).stream():
            snap.reference.delete()
