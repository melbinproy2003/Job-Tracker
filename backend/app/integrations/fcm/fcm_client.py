"""Firebase Cloud Messaging client wrapper."""

from __future__ import annotations

import logging
from typing import Any

logger = logging.getLogger(__name__)


class FcmClient:
    def send(
        self,
        *,
        token: str,
        title: str,
        body: str,
        data: dict[str, str] | None = None,
    ) -> dict[str, Any]:
        try:
            from firebase_admin import messaging
        except Exception as exc:  # pragma: no cover
            logger.warning("firebase messaging unavailable: %s", exc)
            return {"success": False, "error": "messaging_unavailable"}

        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in (data or {}).items()},
            token=token,
        )
        try:
            message_id = messaging.send(message)
            return {"success": True, "message_id": message_id}
        except Exception as exc:
            logger.warning("FCM send failed: %s", type(exc).__name__)
            return {"success": False, "error": type(exc).__name__}
