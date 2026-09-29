"""Activity schemas."""

from datetime import datetime

from pydantic import BaseModel

from app.models.enums.activity_type import ActivityType


class ActivityResponse(BaseModel):
    id: str
    application_id: str
    type: ActivityType
    title: str
    description: str | None = None
    created_at: datetime
