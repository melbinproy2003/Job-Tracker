"""Dashboard aggregate schemas."""

from datetime import datetime

from pydantic import BaseModel, Field


class DashboardRecentApplication(BaseModel):
    id: str
    company_name: str
    job_title: str
    status: str
    updated_at: datetime | None = None


class DashboardUpcomingEvent(BaseModel):
    id: str
    kind: str  # interview | followup
    title: str
    company_name: str | None = None
    job_title: str | None = None
    scheduled_at: datetime
    application_id: str | None = None


class DashboardResponse(BaseModel):
    total_applications: int = 0
    active_applications: int = 0
    interviews: int = 0
    upcoming_interviews: int = 0
    completed_interviews: int = 0
    pending_followups: int = 0
    overdue_followups: int = 0
    completed_followups: int = 0
    offers: int = 0
    accepted: int = 0
    rejected: int = 0
    followups_due: int = 0
    status_distribution: dict[str, int] = Field(default_factory=dict)
    recent_applications: list[DashboardRecentApplication] = Field(default_factory=list)
    upcoming_events: list[DashboardUpcomingEvent] = Field(default_factory=list)
