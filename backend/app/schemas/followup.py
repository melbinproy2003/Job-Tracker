"""Follow-up schemas."""

from datetime import datetime

from pydantic import BaseModel, Field


class FollowUpCreateRequest(BaseModel):
    application_id: str = Field(..., min_length=1)
    title: str = Field(..., min_length=1)
    scheduled_at: datetime
    notes: str | None = None
    force: bool = False


class FollowUpUpdateRequest(BaseModel):
    title: str | None = None
    scheduled_at: datetime | None = None
    notes: str | None = None
    completed: bool | None = None
    force: bool = False


class FollowUpResponse(BaseModel):
    id: str
    application_id: str
    company_id: str | None = None
    company_name: str | None = None
    job_title: str | None = None
    title: str
    scheduled_at: datetime
    completed: bool = False
    completed_at: datetime | None = None
    notes: str | None = None
    is_overdue: bool = False
    created_at: datetime | None = None
    updated_at: datetime | None = None
