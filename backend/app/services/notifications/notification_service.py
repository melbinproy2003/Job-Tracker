"""In-app notifications, devices, and preferences."""

from __future__ import annotations

from typing import Any

from app.core.exceptions import NotFoundError, ValidationError
from app.models.enums.device_platform import DevicePlatform
from app.models.enums.notification_type import NotificationType
from app.repositories.device_repository import DeviceRepository
from app.repositories.notification_repository import NotificationRepository
from app.schemas.notification import (
    DeviceRegisterRequest,
    DeviceRegisterResponse,
    NotificationPreferences,
    NotificationResponse,
    UnreadCountResponse,
)
from app.services.notifications.fcm_service import FcmService
from app.utils.text import sanitize_text


class NotificationService:
    def __init__(
        self,
        notification_repository: NotificationRepository | None = None,
        device_repository: DeviceRepository | None = None,
        fcm_service: FcmService | None = None,
    ):
        self._notifications = notification_repository or NotificationRepository()
        self._devices = device_repository or DeviceRepository()
        self._fcm = fcm_service or FcmService(device_repository=self._devices)

    def register_device(self, user_id: str, payload: DeviceRegisterRequest) -> DeviceRegisterResponse:
        try:
            platform = DevicePlatform(payload.platform)
        except ValueError as exc:
            raise ValidationError("Invalid platform.", code="INVALID_PLATFORM") from exc

        existing = self._devices.find_by_token(user_id, payload.fcm_token)
        data = {
            "fcm_token": payload.fcm_token,
            "platform": platform.value,
            "device_name": sanitize_text(payload.device_name) or "Device",
            "app_version": sanitize_text(payload.app_version),
            "is_active": True,
        }
        if existing:
            updated = self._devices.update(user_id, existing["id"], data)
            return DeviceRegisterResponse(
                id=updated["id"],
                registered=True,
                platform=platform,
                is_active=True,
            )
        created = self._devices.create(user_id, data)
        return DeviceRegisterResponse(
            id=created["id"],
            registered=True,
            platform=platform,
            is_active=True,
        )

    def delete_device(self, user_id: str, device_id: str) -> None:
        device = self._devices.get(user_id, device_id)
        if not device:
            raise NotFoundError("Device not found.", code="DEVICE_NOT_FOUND")
        self._devices.delete(user_id, device_id)

    def create_and_push(
        self,
        user_id: str,
        *,
        type: NotificationType,
        title: str,
        body: str,
        data: dict[str, Any] | None = None,
        related_application_id: str | None = None,
        related_interview_id: str | None = None,
        related_followup_id: str | None = None,
        dedupe_key: str | None = None,
        push: bool = True,
    ) -> NotificationResponse | None:
        created = self._notifications.create(
            user_id,
            {
                "type": type.value,
                "title": title,
                "body": body,
                "data": data or {},
                "related_application_id": related_application_id,
                "related_interview_id": related_interview_id,
                "related_followup_id": related_followup_id,
                "dedupe_key": dedupe_key,
            },
        )
        if created.get("_duplicate"):
            return None
        if push:
            push_data = {
                "type": type.value,
                "notification_id": created["id"],
                **(data or {}),
            }
            if related_application_id:
                push_data["application_id"] = related_application_id
            if related_interview_id:
                push_data["interview_id"] = related_interview_id
            if related_followup_id:
                push_data["followup_id"] = related_followup_id
            self._fcm.send_to_user(user_id, title=title, body=body, data=push_data)
        return self._to_response(created)

    def list(self, user_id: str) -> list[NotificationResponse]:
        return [self._to_response(n) for n in self._notifications.list(user_id)]

    def unread_count(self, user_id: str) -> UnreadCountResponse:
        return UnreadCountResponse(count=self._notifications.unread_count(user_id))

    def mark_read(self, user_id: str, notification_id: str) -> NotificationResponse:
        updated = self._notifications.mark_read(user_id, notification_id)
        if not updated:
            raise NotFoundError("Notification not found.", code="NOTIFICATION_NOT_FOUND")
        return self._to_response(updated)

    def mark_all_read(self, user_id: str) -> dict[str, int]:
        return {"updated": self._notifications.mark_all_read(user_id)}

    def delete(self, user_id: str, notification_id: str) -> None:
        if not self._notifications.delete(user_id, notification_id):
            raise NotFoundError("Notification not found.", code="NOTIFICATION_NOT_FOUND")

    def get_preferences(self, user_id: str) -> NotificationPreferences:
        return NotificationPreferences(**self._notifications.get_preferences(user_id))

    def update_preferences(
        self, user_id: str, prefs: NotificationPreferences
    ) -> NotificationPreferences:
        saved = self._notifications.set_preferences(user_id, prefs.model_dump())
        return NotificationPreferences(**saved)

    def _to_response(self, data: dict[str, Any]) -> NotificationResponse:
        return NotificationResponse(
            id=data["id"],
            type=NotificationType(data.get("type") or NotificationType.SYSTEM.value),
            title=data.get("title") or "",
            body=data.get("body") or "",
            data=data.get("data"),
            related_application_id=data.get("related_application_id"),
            related_interview_id=data.get("related_interview_id"),
            related_followup_id=data.get("related_followup_id"),
            read=bool(data.get("read")),
            sent_at=data.get("sent_at"),
            created_at=data.get("created_at"),
            expires_at=data.get("expires_at"),
        )
