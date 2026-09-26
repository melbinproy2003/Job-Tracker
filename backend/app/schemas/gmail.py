"""Gmail integration schemas. Tokens are never included in responses."""

from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field

from app.models.enums.application_status import ApplicationStatus
from app.models.enums.gmail_match_status import GmailMatchStatus


class GmailConnectResponse(BaseModel):
    authorization_url: str


class GmailAccountResponse(BaseModel):
    id: str
    email: str
    connected: bool = True
    last_sync_at: datetime | None = None
    scopes: list[str] = Field(default_factory=list)


class GmailSyncRequest(BaseModel):
    full_sync: bool = False


class GmailSyncResponse(BaseModel):
    success: bool = True
    messages_checked: int = 0
    job_related_found: int = 0
    matches_suggested: int = 0
    last_sync_at: datetime | None = None
    message: str | None = None


class GmailThreadResponse(BaseModel):
    id: str
    gmail_thread_id: str
    subject: str | None = None
    snippet: str | None = None
    participants: list[str] = Field(default_factory=list)
    last_message_at: datetime | None = None
    application_id: str | None = None
    match_status: GmailMatchStatus = GmailMatchStatus.UNMATCHED
    is_job_related: bool = False
    suggested_status: ApplicationStatus | None = None
    match_confidence: int | None = None
    match_confidence_label: str | None = None
    interview_suggestion: dict[str, Any] | None = None


class GmailMessageResponse(BaseModel):
    id: str
    gmail_message_id: str
    gmail_thread_id: str
    from_address: str | None = None
    to_address: str | None = None
    subject: str | None = None
    snippet: str | None = None
    received_at: datetime | None = None
    body_text: str | None = None
    application_id: str | None = None
    is_job_related: bool = False
    detected_category: str | None = None


class GmailMatchConfirmRequest(BaseModel):
    application_id: str = Field(..., min_length=1)
    confirm_status: ApplicationStatus | None = None
    create_interview: bool = False
    interview: dict[str, Any] | None = None


class GmailMatchResponse(BaseModel):
    thread_id: str
    application_id: str | None = None
    match_status: GmailMatchStatus
    suggested_status: ApplicationStatus | None = None
    applied: bool = False
    interview_created: bool = False
