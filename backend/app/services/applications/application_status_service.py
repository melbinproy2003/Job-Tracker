"""Application status transitions with immutable history."""

from __future__ import annotations

from app.core.exceptions import ApplicationNotFoundError, InvalidApplicationStatusError
from app.models.enums.activity_type import ActivityType
from app.models.enums.application_status import ApplicationStatus
from app.repositories.application_history_repository import ApplicationHistoryRepository
from app.repositories.application_repository import ApplicationRepository
from app.schemas.application import (
    ApplicationResponse,
    ApplicationStatusHistoryResponse,
    ApplicationStatusUpdateRequest,
)
from app.services.activities.activity_service import ActivityService
from app.utils.text import sanitize_text


class ApplicationStatusService:
    def __init__(
        self,
        application_repository: ApplicationRepository | None = None,
        history_repository: ApplicationHistoryRepository | None = None,
        activity_service: ActivityService | None = None,
    ):
        self._apps = application_repository or ApplicationRepository()
        self._history = history_repository or ApplicationHistoryRepository()
        self._activities = activity_service or ActivityService(
            application_repository=self._apps
        )

    def change_status(
        self,
        user_id: str,
        application_id: str,
        payload: ApplicationStatusUpdateRequest,
    ) -> ApplicationResponse:
        app = self._apps.get(user_id, application_id)
        if not app:
            raise ApplicationNotFoundError()

        try:
            new_status = ApplicationStatus(payload.status)
        except ValueError as exc:
            raise InvalidApplicationStatusError() from exc

        current = app.get("status")
        if current == new_status.value:
            return _to_application_response(app)

        updated = self._apps.update(
            user_id,
            application_id,
            {"status": new_status.value},
        )
        self._history.append(
            user_id,
            application_id,
            previous_status=current,
            new_status=new_status.value,
            note=sanitize_text(payload.note),
        )
        prev_label = current or "—"
        self._activities.record(
            user_id,
            application_id,
            type=ActivityType.STATUS_CHANGED,
            title="Status changed",
            description=f"{prev_label} → {new_status.value}",
        )
        return _to_application_response(updated)

    def get_history(
        self, user_id: str, application_id: str
    ) -> list[ApplicationStatusHistoryResponse]:
        app = self._apps.get(user_id, application_id)
        if not app:
            raise ApplicationNotFoundError()
        rows = self._history.list(user_id, application_id)
        result: list[ApplicationStatusHistoryResponse] = []
        for row in rows:
            prev = row.get("previous_status")
            result.append(
                ApplicationStatusHistoryResponse(
                    id=row["id"],
                    application_id=application_id,
                    previous_status=ApplicationStatus(prev) if prev else None,
                    new_status=ApplicationStatus(row["new_status"]),
                    note=row.get("note"),
                    changed_at=row["changed_at"],
                )
            )
        return result


def _to_application_response(data: dict) -> ApplicationResponse:
    from app.services.applications.application_service import to_application_response

    return to_application_response(data)
