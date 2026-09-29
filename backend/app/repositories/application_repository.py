"""Application repository — user-scoped Firestore access."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from google.cloud.firestore import Client

from app.integrations.firebase.firestore_client import get_firestore_client


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


class ApplicationRepository:
    def __init__(self, client: Client | None = None):
        self._client = client

    @property
    def client(self) -> Client:
        if self._client is None:
            self._client = get_firestore_client()
        return self._client

    def _col(self, user_id: str):
        return self.client.collection("users").document(user_id).collection("applications")

    def create(self, user_id: str, data: dict[str, Any]) -> dict[str, Any]:
        now = _utc_now()
        ref = self._col(user_id).document()
        payload = {
            **data,
            "id": ref.id,
            "user_id": user_id,
            "created_at": now,
            "updated_at": now,
            "last_updated_at": now,
        }
        ref.set(payload)
        return payload

    def get(self, user_id: str, application_id: str) -> dict[str, Any] | None:
        snap = self._col(user_id).document(application_id).get()
        if not snap.exists:
            return None
        data = snap.to_dict() or {}
        data["id"] = snap.id
        return data

    def list_all(self, user_id: str) -> list[dict[str, Any]]:
        items: list[dict[str, Any]] = []
        for snap in self._col(user_id).stream():
            data = snap.to_dict() or {}
            data["id"] = snap.id
            items.append(data)
        return items

    def list_by_company(self, user_id: str, company_id: str) -> list[dict[str, Any]]:
        query = self._col(user_id).where("company_id", "==", company_id)
        items: list[dict[str, Any]] = []
        for snap in query.stream():
            data = snap.to_dict() or {}
            data["id"] = snap.id
            items.append(data)
        return items

    def count_by_company(self, user_id: str, company_id: str) -> int:
        return len(self.list_by_company(user_id, company_id))

    def update(self, user_id: str, application_id: str, data: dict[str, Any]) -> dict[str, Any]:
        now = _utc_now()
        payload = {**data, "updated_at": now, "last_updated_at": now}
        ref = self._col(user_id).document(application_id)
        ref.set(payload, merge=True)
        return self.get(user_id, application_id) or {"id": application_id, **payload}

    def delete(self, user_id: str, application_id: str) -> None:
        self._col(user_id).document(application_id).delete()
