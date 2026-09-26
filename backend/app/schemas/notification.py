"""Notification and device schemas."""

from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field

from app.models.enums.device_platform import DevicePlatform
from app.models.enums.notification_type import NotificationType


class DeviceRegisterRequest(BaseModel):
    fcm_token: str = Field(..., min_length=10)
    platform: DevicePlatform
    device_name: str | None = None
    app_version: str | None = None


class DeviceRegisterResponse(BaseModel):
    id: str
    registered: bool = True
    platform: DevicePlatform
    is_active: bool = True


class NotificationPreferences(BaseModel):
    interview_reminders: bool = True
    followup_reminders: bool = True
    overdue_followups: bool = True
    gmail_notifications: bool = True
    application_suggestions: bool = True


class NotificationResponse(BaseModel):
    id: str
    type: NotificationType
    title: str
    body: str
    data: dict[str, Any] | None = None
    related_application_id: str | None = None
    related_interview_id: str | None = None
    related_followup_id: str | None = None
    read: bool = False
    sent_at: datetime | None = None
    created_at: datetime | None = None
    expires_at: datetime | None = None


class UnreadCountResponse(BaseModel):
    count: int
