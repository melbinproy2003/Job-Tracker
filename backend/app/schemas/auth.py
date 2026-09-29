"""Auth request/response schemas."""

from pydantic import BaseModel, Field


class AuthUserResponse(BaseModel):
    id: str = Field(..., description="Firebase UID — permanent user identifier")
    email: str | None = None
    display_name: str | None = None
    photo_url: str | None = None
    email_verified: bool = False


class AuthHealthResponse(BaseModel):
    status: str = "ok"
