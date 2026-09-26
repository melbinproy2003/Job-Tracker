"""Follow-up domain model."""

from datetime import datetime

from pydantic import BaseModel


class FollowUp(BaseModel):
    id: str | None = None
    user_id: str
    application_id: str
    due_at: datetime
    channel: str | None = None
    notes: str | None = None
    completed: bool = False
    completed_at: datetime | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None
