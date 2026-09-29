"""Resume schemas."""

from datetime import datetime

from pydantic import BaseModel


class ResumeResponse(BaseModel):
    id: str
    user_id: str
    name: str
    storage_path: str | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None
