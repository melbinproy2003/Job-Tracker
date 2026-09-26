"""Company repository — user-scoped Firestore access."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from google.cloud.firestore import Client

from app.integrations.firebase.firestore_client import get_firestore_client
from app.utils.text import normalize_company_name


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


class CompanyRepository:
    def __init__(self, client: Client | None = None):
        self._client = client

    @property
    def client(self) -> Client:
        if self._client is None:
            self._client = get_firestore_client()
        return self._client

    def _col(self, user_id: str):
        return self.client.collection("users").document(user_id).collection("companies")

    def create(self, user_id: str, data: dict[str, Any]) -> dict[str, Any]:
        now = _utc_now()
        ref = self._col(user_id).document()
        payload = {
            **data,
            "id": ref.id,
            "user_id": user_id,
            "name_normalized": normalize_company_name(data["name"]),
            "created_at": now,
            "updated_at": now,
        }
        ref.set(payload)
        return payload

    def get(self, user_id: str, company_id: str) -> dict[str, Any] | None:
        snap = self._col(user_id).document(company_id).get()
        if not snap.exists:
            return None
        data = snap.to_dict() or {}
        data["id"] = snap.id
        return data

    def list(self, user_id: str) -> list[dict[str, Any]]:
        docs = self._col(user_id).stream()
        items: list[dict[str, Any]] = []
        for snap in docs:
            data = snap.to_dict() or {}
            data["id"] = snap.id
            items.append(data)
        items.sort(key=lambda x: (x.get("name") or "").lower())
        return items

    def find_by_normalized_name(self, user_id: str, name: str) -> dict[str, Any] | None:
        normalized = normalize_company_name(name)
        query = self._col(user_id).where("name_normalized", "==", normalized).limit(1)
        for snap in query.stream():
            data = snap.to_dict() or {}
            data["id"] = snap.id
            return data
        return None

    def update(self, user_id: str, company_id: str, data: dict[str, Any]) -> dict[str, Any]:
        payload = {**data, "updated_at": _utc_now()}
        if "name" in payload and payload["name"]:
            payload["name_normalized"] = normalize_company_name(payload["name"])
        ref = self._col(user_id).document(company_id)
        ref.set(payload, merge=True)
        return self.get(user_id, company_id) or {"id": company_id, **payload}

    def delete(self, user_id: str, company_id: str) -> None:
        self._col(user_id).document(company_id).delete()
