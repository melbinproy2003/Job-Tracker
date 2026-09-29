"""Gmail integration schemas. Tokens are never included in responses."""

from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field

from app.models.enums.application_status import ApplicationStatus
from app.models.enums.gmail_match_status import GmailMatchStatus
from app.models.enums.interview_type import InterviewType


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


class InterviewSuggestion(BaseModel):
    """Phase 6 interview extraction contract (Python ↔ Flutter)."""

    title: str | None = None
    scheduled_at: datetime | None = None
    duration_minutes: int | None = None
    meeting_url: str | None = None
    location: str | None = None
    interviewer_name: str | None = None
    interviewer_email: str | None = None
    interview_type: InterviewType | str | None = None
    # Alias for older clients
    type: InterviewType | str | None = None
    confidence: float | None = None


class MatchCandidate(BaseModel):
    application_id: str
    company_name: str | None = None
    job_title: str | None = None
    score: float | None = None
    confidence: int
    confidence_label: str | None = None
    confidence_band: str | None = None
    reasons: list[str] = Field(default_factory=list)


class ApplicationDraftFromEmail(BaseModel):
    company_name: str | None = None
    company_domain: str | None = None
    job_title: str | None = None
    job_url: str | None = None
    location: str | None = None
    recruiter_name: str | None = None
    recruiter_email: str | None = None
    source: str = "Gmail"
    notes: str | None = None
    applied_at: datetime | None = None
    from_address: str | None = None
    subject: str | None = None


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
    detected_category: str | None = None
    detection_confidence: float | None = None
    matched_signals: list[str] = Field(default_factory=list)
    suggested_status: ApplicationStatus | None = None
    match_confidence: int | None = None
    match_confidence_label: str | None = None
    interview_suggestion: InterviewSuggestion | dict[str, Any] | None = None
    match_candidates: list[MatchCandidate] = Field(default_factory=list)
    application_draft: ApplicationDraftFromEmail | dict[str, Any] | None = None


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
    detection_confidence: float | None = None
    matched_signals: list[str] = Field(default_factory=list)


class GmailTimelineEvent(BaseModel):
    id: str
    kind: str  # category | status_suggestion | interview | linked
    title: str
    occurred_at: datetime | None = None
    category: str | None = None
    thread_id: str | None = None
    message_id: str | None = None


class GmailMatchConfirmRequest(BaseModel):
    application_id: str = Field(..., min_length=1)
    confirm_status: ApplicationStatus | None = None
    create_interview: bool = False
    interview: dict[str, Any] | None = None
    # When true after user acknowledges a conflict warning.
    force_interview: bool = False


class GmailMatchResponse(BaseModel):
    thread_id: str
    application_id: str | None = None
    match_status: GmailMatchStatus
    suggested_status: ApplicationStatus | None = None
    applied: bool = False
    interview_created: bool = False
    already_applied: bool = False
    interview_conflict: bool = False
    conflict_message: str | None = None
    interview_id: str | None = None


class GmailUnlinkRequest(BaseModel):
    pass


class GmailRetentionCleanupResponse(BaseModel):
    messages_cleared: int = 0
    message: str | None = None
