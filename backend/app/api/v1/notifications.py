"""Notification and device registration endpoints.

Handlers are declared ``def`` (not ``async def``) because they delegate to
synchronous Firestore Admin SDK operations. FastAPI will execute sync handlers
in its threadpool, preventing event-loop blocking under concurrent requests.
"""

from typing import Annotated

from fastapi import APIRouter, Depends

from app.api.v1.dependencies import get_current_user_id
from app.schemas.notification import (
    DeviceRegisterRequest,
    DeviceRegisterResponse,
    NotificationPreferences,
    NotificationResponse,
    UnreadCountResponse,
)
from app.services.notifications.notification_service import NotificationService
from app.services.notifications.reminder_service import ReminderService

router = APIRouter()


def get_notification_service() -> NotificationService:
    return NotificationService()


def get_reminder_service() -> ReminderService:
    return ReminderService()


@router.post("/devices", response_model=DeviceRegisterResponse, status_code=201)
def register_device(
    payload: DeviceRegisterRequest,
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[NotificationService, Depends(get_notification_service)],
) -> DeviceRegisterResponse:
    return service.register_device(user_id, payload)


@router.delete("/devices/{device_id}", status_code=204)
def delete_device(
    device_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[NotificationService, Depends(get_notification_service)],
) -> None:
    service.delete_device(user_id, device_id)


@router.get("", response_model=list[NotificationResponse])
def list_notifications(
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[NotificationService, Depends(get_notification_service)],
) -> list[NotificationResponse]:
    return service.list(user_id)


@router.get("/unread-count", response_model=UnreadCountResponse)
def unread_count(
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[NotificationService, Depends(get_notification_service)],
) -> UnreadCountResponse:
    return service.unread_count(user_id)


@router.patch("/{notification_id}/read", response_model=NotificationResponse)
def mark_notification_read(
    notification_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[NotificationService, Depends(get_notification_service)],
) -> NotificationResponse:
    return service.mark_read(user_id, notification_id)


@router.patch("/read-all")
def mark_all_read(
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[NotificationService, Depends(get_notification_service)],
) -> dict:
    return service.mark_all_read(user_id)


@router.delete("/{notification_id}", status_code=204)
def delete_notification(
    notification_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[NotificationService, Depends(get_notification_service)],
) -> None:
    service.delete(user_id, notification_id)


@router.get("/preferences", response_model=NotificationPreferences)
def get_preferences(
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[NotificationService, Depends(get_notification_service)],
) -> NotificationPreferences:
    return service.get_preferences(user_id)


@router.put("/preferences", response_model=NotificationPreferences)
def update_preferences(
    payload: NotificationPreferences,
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[NotificationService, Depends(get_notification_service)],
) -> NotificationPreferences:
    return service.update_preferences(user_id, payload)


@router.post("/process-reminders")
def process_reminders(
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[ReminderService, Depends(get_reminder_service)],
) -> dict:
    """Dev/ops endpoint: process interview/follow-up reminders for the current user."""
    return service.process_user(user_id)
