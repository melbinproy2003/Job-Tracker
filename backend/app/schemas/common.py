"""Shared API schemas."""

from datetime import datetime
from typing import Any, Generic, TypeVar

from pydantic import BaseModel, Field

T = TypeVar("T")


class MessageResponse(BaseModel):
    message: str


class ErrorResponse(BaseModel):
    code: str
    message: str
    details: Any | None = None


class PaginatedResponse(BaseModel, Generic[T]):
    items: list[T]
    total: int = 0
    limit: int = 50
    offset: int = 0


class TimestampMixin(BaseModel):
    created_at: datetime | None = None
    updated_at: datetime | None = None


class IdResponse(BaseModel):
    id: str = Field(..., description="Resource identifier")
