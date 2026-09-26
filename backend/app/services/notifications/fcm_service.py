"""Send push notifications to a user's registered devices."""

from __future__ import annotations

from typing import Any

from app.integrations.fcm.fcm_client import FcmClient
from app.repositories.device_repository import DeviceRepository


class FcmService:
    def __init__(
        self,
        device_repository: DeviceRepository | None = None,
        fcm_client: FcmClient | None = None,
    ):
        self._devices = device_repository or DeviceRepository()
        self._fcm = fcm_client or FcmClient()

    def send_to_user(
        self,
        user_id: str,
        *,
        title: str,
        body: str,
        data: dict[str, Any] | None = None,
    ) -> list[dict[str, Any]]:
        results = []
        payload = {k: str(v) for k, v in (data or {}).items() if v is not None}
        for device in self._devices.list_active(user_id):
            token = device.get("fcm_token")
            if not token:
                continue
            result = self._fcm.send(token=token, title=title, body=body, data=payload)
            results.append({"device_id": device.get("id"), **result})
            # Deactivate invalid tokens
            err = (result.get("error") or "").lower()
            if "unregistered" in err or "invalid" in err:
                self._devices.deactivate(user_id, device["id"])
        return results
