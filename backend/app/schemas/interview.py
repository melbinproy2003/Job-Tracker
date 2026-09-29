"""Interview schemas."""

from datetime import datetime

from pydantic import BaseModel, Field, field_validator

from app.models.enums.interview_status import InterviewStatus
from app.models.enums.interview_type import InterviewType


class InterviewCreateRequest(BaseModel):
    type: InterviewType
    title: str | None = None
    scheduled_at: datetime
    duration_minutes: int | None = 60
    meeting_url: str | None = None
    location: str | None = None
    interviewer_name: str | None = None
    interviewer_email: str | None = None
    notes: str | None = None
    status: InterviewStatus = InterviewStatus.SCHEDULED
    force: bool = False  # override conflict warning

    @field_validator("duration_minutes")
    @classmethod
    def positive_duration(cls, v: int | None) -> int | None:
        if v is not None and v <= 0:
            raise ValueError("Duration must be positive.")
        return v

    @field_validator("meeting_url")
    @classmethod
    def validate_url(cls, v: str | None) -> str | None:
        if v is None or not v.strip():
            return None
        value = v.strip()
        if not value.startswith(("http://", "https://")):
            raise ValueError("Meeting URL must be a valid URL.")
        return value

    @field_validator("interviewer_email")
    @classmethod
    def validate_email(cls, v: str | None) -> str | None:
        if v is None or not str(v).strip():
            return None
        value = str(v).strip().lower()
        if "@" not in value or "." not in value.split("@")[-1]:
            raise ValueError("Invalid interviewer email.")
        return value


class InterviewUpdateRequest(BaseModel):
    type: InterviewType | None = None
    title: str | None = None
    scheduled_at: datetime | None = None
    duration_minutes: int | None = None
    meeting_url: str | None = None
    location: str | None = None
    interviewer_name: str | None = None
    interviewer_email: str | None = None
    notes: str | None = None
    status: InterviewStatus | None = None
    force: bool = False

    @field_validator("duration_minutes")
    @classmethod
    def positive_duration(cls, v: int | None) -> int | None:
        if v is not None and v <= 0:
            raise ValueError("Duration must be positive.")
        return v

    @field_validator("meeting_url")
    @classmethod
    def validate_url(cls, v: str | None) -> str | None:
        if v is None or not str(v).strip():
            return None
        value = str(v).strip()
        if not value.startswith(("http://", "https://")):
            raise ValueError("Meeting URL must be a valid URL.")
        return value

    @field_validator("interviewer_email")
    @classmethod
    def validate_email(cls, v: str | None) -> str | None:
        if v is None or not str(v).strip():
            return None
        value = str(v).strip().lower()
        if "@" not in value or "." not in value.split("@")[-1]:
            raise ValueError("Invalid interviewer email.")
        return value


class InterviewResponse(BaseModel):
    id: str
    application_id: str
    company_id: str | None = None
    company_name: str | None = None
    job_title: str | None = None
    type: InterviewType
    title: str | None = None
    scheduled_at: datetime
    duration_minutes: int | None = None
    meeting_url: str | None = None
    location: str | None = None
    interviewer_name: str | None = None
    interviewer_email: str | None = None
    notes: str | None = None
    status: InterviewStatus
    created_at: datetime | None = None
    updated_at: datetime | None = None


class InterviewConflictResponse(BaseModel):
    conflict: bool = True
    message: str
    overlapping_interview_ids: list[str] = Field(default_factory=list)
