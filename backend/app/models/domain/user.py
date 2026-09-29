"""User domain model."""

from datetime import datetime

from pydantic import BaseModel, EmailStr


class User(BaseModel):
    id: str
    email: EmailStr | None = None
    display_name: str | None = None
    photo_url: str | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None
