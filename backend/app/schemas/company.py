"""Company schemas."""

from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field, field_validator, HttpUrl


class CompanyCreateRequest(BaseModel):
    name: str = Field(..., min_length=1)
    website: str | None = None
    location: str | None = None
    industry: str | None = None
    notes: str | None = None

    @field_validator("name")
    @classmethod
    def name_not_blank(cls, v: str) -> str:
        cleaned = v.strip()
        if not cleaned:
            raise ValueError("Company name is required.")
        return cleaned

    @field_validator("website")
    @classmethod
    def validate_website(cls, v: str | None) -> str | None:
        if v is None or not v.strip():
            return None
        value = v.strip()
        if not (value.startswith("http://") or value.startswith("https://")):
            raise ValueError("Website must be a valid URL.")
        return value


class CompanyUpdateRequest(BaseModel):
    name: str | None = None
    website: str | None = None
    location: str | None = None
    industry: str | None = None
    notes: str | None = None

    @field_validator("name")
    @classmethod
    def name_not_blank(cls, v: str | None) -> str | None:
        if v is None:
            return None
        cleaned = v.strip()
        if not cleaned:
            raise ValueError("Company name cannot be empty.")
        return cleaned

    @field_validator("website")
    @classmethod
    def validate_website(cls, v: str | None) -> str | None:
        if v is None or not str(v).strip():
            return None
        value = str(v).strip()
        if not (value.startswith("http://") or value.startswith("https://")):
            raise ValueError("Website must be a valid URL.")
        return value


class CompanyResponse(BaseModel):
    id: str
    name: str
    website: str | None = None
    location: str | None = None
    industry: str | None = None
    notes: str | None = None
    application_count: int = 0
    created_at: datetime | None = None
    updated_at: datetime | None = None


class CompanyDetailResponse(CompanyResponse):
    applications: list[dict[str, Any]] = Field(default_factory=list)
