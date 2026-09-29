"""Application domain model (central entity)."""

from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field

from app.models.enums.application_status import ApplicationStatus


class Application(BaseModel):
    id: str | None = None
    user_id: str
    company_id: str | None = None
    company_name: str
    job_title: str
    job_url: str | None = None
    location: str | None = None
    source: str | None = None
    employment_type: str | None = None
    status: ApplicationStatus = ApplicationStatus.SAVED
    applied_at: datetime | None = None
    last_updated_at: datetime | None = None
    recruiter_name: str | None = None
    recruiter_email: str | None = None
    salary_min: float | None = None
    salary_max: float | None = None
    currency: str | None = None
    resume_id: str | None = None
    cover_letter: str | None = None
    notes: str | None = None
    gmail_thread_id: str | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None
    extra: dict[str, Any] = Field(default_factory=dict)
