"""User schemas."""

from datetime import datetime

from pydantic import BaseModel, EmailStr


class UserResponse(BaseModel):
    id: str
    email: EmailStr | None = None
    display_name: str | None = None
    photo_url: str | None = None
    email_verified: bool = False
    created_at: datetime | None = None
    updated_at: datetime | None = None
    last_login_at: datetime | None = None


class UserUpdateRequest(BaseModel):
    display_name: str | None = None
