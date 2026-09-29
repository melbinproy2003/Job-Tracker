"""Gmail account credentials repository (encrypted tokens)."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from google.cloud.firestore import Client

from app.integrations.firebase.firestore_client import get_firestore_client


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


class GmailAccountRepository:
    def __init__(self, client: Client | None = None):
        self._client = client

    @property
    def client(self) -> Client:
        if self._client is None:
            self._client = get_firestore_client()
        return self._client

    def _col(self, user_id: str):
        return self.client.collection("users").document(user_id).collection("gmail_accounts")

    def create(self, user_id: str, data: dict[str, Any]) -> dict[str, Any]:
        now = _utc_now()
        ref = self._col(user_id).document()
        payload = {
            **data,
            "id": ref.id,
            "user_id": user_id,
            "provider": "google",
            "connected": True,
            "created_at": now,
            "updated_at": now,
        }
        ref.set(payload)
        return payload

    def upsert_by_email(self, user_id: str, email: str, data: dict[str, Any]) -> dict[str, Any]:
        existing = self.find_by_email(user_id, email)
        if existing:
            return self.update(user_id, existing["id"], {**data, "connected": True})
        return self.create(user_id, {**data, "email": email})

    def find_by_email(self, user_id: str, email: str) -> dict[str, Any] | None:
        email_l = email.strip().lower()
        for item in self.list(user_id):
            if (item.get("email") or "").lower() == email_l:
                return item
        return None

    def get(self, user_id: str, account_id: str) -> dict[str, Any] | None:
        snap = self._col(user_id).document(account_id).get()
        if not snap.exists:
            return None
        data = snap.to_dict() or {}
        data["id"] = snap.id
        return data

    def list(self, user_id: str) -> list[dict[str, Any]]:
        items = []
        for snap in self._col(user_id).stream():
            data = snap.to_dict() or {}
            data["id"] = snap.id
            items.append(data)
        return items

    def get_primary(self, user_id: str) -> dict[str, Any] | None:
        connected = [a for a in self.list(user_id) if a.get("connected")]
        return connected[0] if connected else None

    def update(self, user_id: str, account_id: str, data: dict[str, Any]) -> dict[str, Any]:
        payload = {**data, "updated_at": _utc_now()}
        ref = self._col(user_id).document(account_id)
        ref.set(payload, merge=True)
        return self.get(user_id, account_id) or {"id": account_id, **payload}

    def delete_credentials(self, user_id: str, account_id: str) -> None:
        self.update(
            user_id,
            account_id,
            {
                "connected": False,
                "encrypted_access_token": None,
                "encrypted_refresh_token": None,
                "token_expires_at": None,
            },
        )

    def delete(self, user_id: str, account_id: str) -> None:
        self._col(user_id).document(account_id).delete()
