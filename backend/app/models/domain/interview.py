"""Interview domain model."""

from datetime import datetime

from pydantic import BaseModel

from app.models.enums.interview_type import InterviewType


class Interview(BaseModel):
    id: str | None = None
    user_id: str
    application_id: str
    interview_type: InterviewType = InterviewType.OTHER
    scheduled_at: datetime | None = None
    location_or_link: str | None = None
    interviewer_name: str | None = None
    notes: str | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None
