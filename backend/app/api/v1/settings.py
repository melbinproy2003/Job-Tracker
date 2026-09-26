"""User settings endpoints."""

from typing import Annotated

from fastapi import APIRouter, Depends

from app.api.v1.dependencies import get_current_user_id
from app.schemas.notification import NotificationPreferences
from app.services.notifications.notification_service import NotificationService

router = APIRouter()


def get_notification_service() -> NotificationService:
    return NotificationService()


@router.get("/notifications", response_model=NotificationPreferences)
async def get_notification_settings(
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[NotificationService, Depends(get_notification_service)],
) -> NotificationPreferences:
    return service.get_preferences(user_id)


@router.put("/notifications", response_model=NotificationPreferences)
async def update_notification_settings(
    payload: NotificationPreferences,
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[NotificationService, Depends(get_notification_service)],
) -> NotificationPreferences:
    return service.update_preferences(user_id, payload)
