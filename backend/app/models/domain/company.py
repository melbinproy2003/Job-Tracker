"""Company domain model."""

from datetime import datetime

from pydantic import BaseModel


class Company(BaseModel):
    id: str | None = None
    user_id: str
    name: str
    website: str | None = None
    careers_url: str | None = None
    location: str | None = None
    notes: str | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None
