"""Application activity business logic."""

from __future__ import annotations

from typing import Any

from app.core.exceptions import ApplicationNotFoundError
from app.models.enums.activity_type import ActivityType
from app.repositories.activity_repository import ActivityRepository
from app.repositories.application_repository import ApplicationRepository
from app.schemas.activity import ActivityResponse


class ActivityService:
    def __init__(
        self,
        activity_repository: ActivityRepository | None = None,
        application_repository: ApplicationRepository | None = None,
    ):
        self._activities = activity_repository or ActivityRepository()
        self._apps = application_repository or ApplicationRepository()

    def record(
        self,
        user_id: str,
        application_id: str,
        *,
        type: ActivityType,
        title: str,
        description: str | None = None,
    ) -> ActivityResponse:
        created = self._activities.create(
            user_id,
            application_id,
            {
                "type": type.value,
                "title": title,
                "description": description,
            },
        )
        return _to_response(created)

    def list_for_application(self, user_id: str, application_id: str) -> list[ActivityResponse]:
        app = self._apps.get(user_id, application_id)
        if not app:
            raise ApplicationNotFoundError()
        rows = self._activities.list(user_id, application_id)
        return [_to_response(r) for r in rows]


def _to_response(data: dict[str, Any]) -> ActivityResponse:
    return ActivityResponse(
        id=data["id"],
        application_id=data["application_id"],
        type=ActivityType(data["type"]),
        title=data.get("title") or "",
        description=data.get("description"),
        created_at=data["created_at"],
    )
