"""Interview repository — nested under user applications."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from google.cloud.firestore import Client

from app.integrations.firebase.firestore_client import get_firestore_client


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


class InterviewRepository:
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
            .collection("interviews")
        )

    def create(self, user_id: str, application_id: str, data: dict[str, Any]) -> dict[str, Any]:
        now = _utc_now()
        ref = self._col(user_id, application_id).document()
        payload = {
            **data,
            "id": ref.id,
            "user_id": user_id,
            "application_id": application_id,
            "created_at": now,
            "updated_at": now,
        }
        ref.set(payload)
        return payload

    def get(self, user_id: str, application_id: str, interview_id: str) -> dict[str, Any] | None:
        snap = self._col(user_id, application_id).document(interview_id).get()
        if not snap.exists:
            return None
        data = snap.to_dict() or {}
        data["id"] = snap.id
        return data

    def list_for_application(self, user_id: str, application_id: str) -> list[dict[str, Any]]:
        items: list[dict[str, Any]] = []
        for snap in self._col(user_id, application_id).stream():
            data = snap.to_dict() or {}
            data["id"] = snap.id
            items.append(data)
        items.sort(key=lambda x: x.get("scheduled_at") or datetime.min.replace(tzinfo=timezone.utc))
        return items

    def list_all_for_user(self, user_id: str, application_ids: list[str]) -> list[dict[str, Any]]:
        items: list[dict[str, Any]] = []
        for application_id in application_ids:
            items.extend(self.list_for_application(user_id, application_id))
        return items

    def find_by_id(self, user_id: str, interview_id: str, application_ids: list[str]) -> dict[str, Any] | None:
        for application_id in application_ids:
            found = self.get(user_id, application_id, interview_id)
            if found:
                return found
        return None

    def update(
        self, user_id: str, application_id: str, interview_id: str, data: dict[str, Any]
    ) -> dict[str, Any]:
        now = _utc_now()
        payload = {**data, "updated_at": now}
        ref = self._col(user_id, application_id).document(interview_id)
        ref.set(payload, merge=True)
        return self.get(user_id, application_id, interview_id) or {"id": interview_id, **payload}

    def delete(self, user_id: str, application_id: str, interview_id: str) -> None:
        self._col(user_id, application_id).document(interview_id).delete()

    def delete_all_for_application(self, user_id: str, application_id: str) -> None:
        for snap in self._col(user_id, application_id).stream():
            snap.reference.delete()
