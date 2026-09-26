"""FCM device token repository."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from google.cloud.firestore import Client

from app.integrations.firebase.firestore_client import get_firestore_client


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


class DeviceRepository:
    def __init__(self, client: Client | None = None):
        self._client = client

    @property
    def client(self) -> Client:
        if self._client is None:
            self._client = get_firestore_client()
        return self._client

    def _col(self, user_id: str):
        return self.client.collection("users").document(user_id).collection("devices")

    def find_by_token(self, user_id: str, fcm_token: str) -> dict[str, Any] | None:
        for snap in self._col(user_id).where("fcm_token", "==", fcm_token).stream():
            data = snap.to_dict() or {}
            data["id"] = snap.id
            return data
        return None

    def create(self, user_id: str, data: dict[str, Any]) -> dict[str, Any]:
        now = _utc_now()
        ref = self._col(user_id).document()
        payload = {
            **data,
            "id": ref.id,
            "user_id": user_id,
            "is_active": True,
            "last_seen_at": now,
            "created_at": now,
            "updated_at": now,
        }
        ref.set(payload)
        return payload

    def update(self, user_id: str, device_id: str, data: dict[str, Any]) -> dict[str, Any]:
        now = _utc_now()
        payload = {**data, "updated_at": now, "last_seen_at": now}
        ref = self._col(user_id).document(device_id)
        ref.set(payload, merge=True)
        snap = ref.get()
        out = snap.to_dict() or payload
        out["id"] = device_id
        return out

    def list_active(self, user_id: str) -> list[dict[str, Any]]:
        items = []
        for snap in self._col(user_id).stream():
            data = snap.to_dict() or {}
            if data.get("is_active", True):
                data["id"] = snap.id
                items.append(data)
        return items

    def get(self, user_id: str, device_id: str) -> dict[str, Any] | None:
        snap = self._col(user_id).document(device_id).get()
        if not snap.exists:
            return None
        data = snap.to_dict() or {}
        data["id"] = snap.id
        return data

    def deactivate(self, user_id: str, device_id: str) -> None:
        self.update(user_id, device_id, {"is_active": False})

    def delete(self, user_id: str, device_id: str) -> None:
        self._col(user_id).document(device_id).delete()
