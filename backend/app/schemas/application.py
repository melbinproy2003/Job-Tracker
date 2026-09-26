"""Application request/response schemas."""

from datetime import datetime
from typing import Any

from pydantic import BaseModel, EmailStr, Field, field_validator, model_validator

from app.models.enums.application_status import ApplicationStatus


class CompanySummary(BaseModel):
    id: str
    name: str


class ApplicationCreateRequest(BaseModel):
    company_id: str = Field(..., min_length=1)
    job_title: str = Field(..., min_length=1)
    job_url: str | None = None
    location: str | None = None
    source: str | None = None
    employment_type: str | None = None
    status: ApplicationStatus = ApplicationStatus.APPLIED
    applied_at: datetime | None = None
    recruiter_name: str | None = None
    recruiter_email: str | None = None
    salary_min: float | None = None
    salary_max: float | None = None
    currency: str | None = "INR"
    resume_id: str | None = None
    cover_letter: str | None = None
    notes: str | None = None
    # user_id / company_name NEVER trusted from client as identity —
    # company_name is denormalized from company record on create.

    @field_validator("job_title")
    @classmethod
    def title_required(cls, v: str) -> str:
        cleaned = v.strip()
        if not cleaned:
            raise ValueError("Job title is required.")
        return cleaned

    @field_validator("job_url")
    @classmethod
    def validate_url(cls, v: str | None) -> str | None:
        if v is None or not v.strip():
            return None
        value = v.strip()
        if not (value.startswith("http://") or value.startswith("https://")):
            raise ValueError("Job URL must be a valid URL.")
        return value

    @field_validator("recruiter_email")
    @classmethod
    def validate_email(cls, v: str | None) -> str | None:
        if v is None or not str(v).strip():
            return None
        return str(v).strip().lower()

    @field_validator("salary_min", "salary_max")
    @classmethod
    def non_negative(cls, v: float | None) -> float | None:
        if v is not None and v < 0:
            raise ValueError("Salary values cannot be negative.")
        return v

    @model_validator(mode="after")
    def salary_range(self) -> "ApplicationCreateRequest":
        if (
            self.salary_min is not None
            and self.salary_max is not None
            and self.salary_min > self.salary_max
        ):
            raise ValueError("salary_min cannot be greater than salary_max.")
        if self.recruiter_email:
            # lightweight email check without requiring EmailStr on optional empty
            if "@" not in self.recruiter_email or "." not in self.recruiter_email.split("@")[-1]:
                raise ValueError("Invalid recruiter email.")
        return self


class ApplicationUpdateRequest(BaseModel):
    company_id: str | None = None
    job_title: str | None = None
    job_url: str | None = None
    location: str | None = None
    source: str | None = None
    employment_type: str | None = None
    applied_at: datetime | None = None
    recruiter_name: str | None = None
    recruiter_email: str | None = None
    salary_min: float | None = None
    salary_max: float | None = None
    currency: str | None = None
    resume_id: str | None = None
    cover_letter: str | None = None
    notes: str | None = None
    # status intentionally omitted — use status endpoint

    @field_validator("job_title")
    @classmethod
    def title_not_blank(cls, v: str | None) -> str | None:
        if v is None:
            return None
        cleaned = v.strip()
        if not cleaned:
            raise ValueError("Job title cannot be empty.")
        return cleaned

    @field_validator("job_url")
    @classmethod
    def validate_url(cls, v: str | None) -> str | None:
        if v is None or not str(v).strip():
            return None
        value = str(v).strip()
        if not (value.startswith("http://") or value.startswith("https://")):
            raise ValueError("Job URL must be a valid URL.")
        return value

    @field_validator("recruiter_email")
    @classmethod
    def validate_email(cls, v: str | None) -> str | None:
        if v is None or not str(v).strip():
            return None
        value = str(v).strip().lower()
        if "@" not in value or "." not in value.split("@")[-1]:
            raise ValueError("Invalid recruiter email.")
        return value

    @field_validator("salary_min", "salary_max")
    @classmethod
    def non_negative(cls, v: float | None) -> float | None:
        if v is not None and v < 0:
            raise ValueError("Salary values cannot be negative.")
        return v

    @model_validator(mode="after")
    def salary_range(self) -> "ApplicationUpdateRequest":
        if (
            self.salary_min is not None
            and self.salary_max is not None
            and self.salary_min > self.salary_max
        ):
            raise ValueError("salary_min cannot be greater than salary_max.")
        return self


class ApplicationStatusUpdateRequest(BaseModel):
    status: ApplicationStatus
    note: str | None = None


class ApplicationResponse(BaseModel):
    id: str
    company: CompanySummary
    job_title: str
    job_url: str | None = None
    location: str | None = None
    source: str | None = None
    employment_type: str | None = None
    status: ApplicationStatus
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
    created_at: datetime | None = None
    updated_at: datetime | None = None


class ApplicationStatusHistoryResponse(BaseModel):
    id: str
    application_id: str
    previous_status: ApplicationStatus | None = None
    new_status: ApplicationStatus
    note: str | None = None
    changed_at: datetime
