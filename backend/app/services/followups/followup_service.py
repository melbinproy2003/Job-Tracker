"""Follow-up business logic."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from app.core.exceptions import (
    ApplicationNotFoundError,
    FollowUpDuplicateError,
    FollowUpNotFoundError,
    InvalidFollowUpError,
)
from app.models.enums.activity_type import ActivityType
from app.repositories.application_repository import ApplicationRepository
from app.repositories.followup_repository import FollowUpRepository
from app.schemas.followup import FollowUpCreateRequest, FollowUpResponse, FollowUpUpdateRequest
from app.services.activities.activity_service import ActivityService
from app.utils.text import sanitize_text


def _ensure_aware(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def _is_overdue(data: dict[str, Any], now: datetime | None = None) -> bool:
    if data.get("completed"):
        return False
    scheduled = data.get("scheduled_at")
    if scheduled is None:
        return False
    now = now or datetime.now(timezone.utc)
    return _ensure_aware(scheduled) < now


class FollowUpService:
    def __init__(
        self,
        followup_repository: FollowUpRepository | None = None,
        application_repository: ApplicationRepository | None = None,
        activity_service: ActivityService | None = None,
    ):
        self._followups = followup_repository or FollowUpRepository()
        self._apps = application_repository or ApplicationRepository()
        self._activities = activity_service or ActivityService(application_repository=self._apps)

    def create(self, user_id: str, payload: FollowUpCreateRequest) -> FollowUpResponse:
        app = self._apps.get(user_id, payload.application_id)
        if not app:
            raise ApplicationNotFoundError()

        title = sanitize_text(payload.title)
        if not title:
            raise InvalidFollowUpError("Title is required.")
        scheduled_at = _ensure_aware(payload.scheduled_at)

        duplicates = [
            f
            for f in self._followups.list_for_application(user_id, payload.application_id)
            if (f.get("title") or "").strip().lower() == title.lower()
            and f.get("scheduled_at")
            and _ensure_aware(f["scheduled_at"]) == scheduled_at
            and not f.get("completed")
        ]
        if duplicates and not payload.force:
            raise FollowUpDuplicateError(
                "A similar follow-up already exists for this application and time."
            )

        data = {
            "application_id": app["id"],
            "company_id": app.get("company_id"),
            "company_name": app.get("company_name"),
            "job_title": app.get("job_title"),
            "title": title,
            "scheduled_at": scheduled_at,
            "completed": False,
            "completed_at": None,
            "notes": sanitize_text(payload.notes),
        }
        created = self._followups.create(user_id, data)
        self._activities.record(
            user_id,
            app["id"],
            type=ActivityType.FOLLOWUP_CREATED,
            title="Follow-up created",
            description=title,
        )
        return self._to_response(created)

    def list(
        self,
        user_id: str,
        *,
        completed: bool | None = None,
        from_date: datetime | None = None,
        to_date: datetime | None = None,
        application_id: str | None = None,
    ) -> list[FollowUpResponse]:
        rows = self._followups.list_all(user_id)
        if application_id:
            rows = [r for r in rows if r.get("application_id") == application_id]
        if completed is not None:
            rows = [r for r in rows if bool(r.get("completed")) is completed]
        if from_date is not None:
            start = _ensure_aware(from_date)
            rows = [
                r
                for r in rows
                if r.get("scheduled_at") and _ensure_aware(r["scheduled_at"]) >= start
            ]
        if to_date is not None:
            end = _ensure_aware(to_date)
            rows = [
                r for r in rows if r.get("scheduled_at") and _ensure_aware(r["scheduled_at"]) <= end
            ]
        return [self._to_response(r) for r in rows]

    def get(self, user_id: str, followup_id: str) -> FollowUpResponse:
        found = self._followups.get(user_id, followup_id)
        if not found:
            raise FollowUpNotFoundError()
        return self._to_response(found)

    def update(
        self, user_id: str, followup_id: str, payload: FollowUpUpdateRequest
    ) -> FollowUpResponse:
        found = self._followups.get(user_id, followup_id)
        if not found:
            raise FollowUpNotFoundError()

        updates = payload.model_dump(exclude_unset=True, exclude={"force"})
        if "title" in updates:
            updates["title"] = sanitize_text(updates.get("title"))
            if not updates["title"]:
                raise InvalidFollowUpError("Title is required.")
        if "notes" in updates:
            updates["notes"] = sanitize_text(updates.get("notes"))
        if "scheduled_at" in updates and updates["scheduled_at"] is not None:
            updates["scheduled_at"] = _ensure_aware(updates["scheduled_at"])

        title = updates.get("title") or found.get("title")
        scheduled_at = updates.get("scheduled_at") or found.get("scheduled_at")
        if title and scheduled_at is not None:
            duplicates = [
                f
                for f in self._followups.list_for_application(user_id, found["application_id"])
                if f.get("id") != followup_id
                and (f.get("title") or "").strip().lower() == str(title).lower()
                and f.get("scheduled_at")
                and _ensure_aware(f["scheduled_at"]) == _ensure_aware(scheduled_at)
                and not f.get("completed")
            ]
            if duplicates and not payload.force:
                raise FollowUpDuplicateError(
                    "A similar follow-up already exists for this application and time."
                )

        if "completed" in updates:
            if updates["completed"] and not found.get("completed"):
                updates["completed_at"] = datetime.now(timezone.utc)
            elif updates["completed"] is False:
                updates["completed_at"] = None

        was_incomplete = not bool(found.get("completed"))
        marking_complete = updates.get("completed") is True

        updated = self._followups.update(user_id, followup_id, updates)

        if marking_complete and was_incomplete:
            self._activities.record(
                user_id,
                found["application_id"],
                type=ActivityType.FOLLOWUP_COMPLETED,
                title="Follow-up completed",
                description=updated.get("title"),
            )
        return self._to_response(updated)

    def complete(self, user_id: str, followup_id: str) -> FollowUpResponse:
        return self.update(
            user_id,
            followup_id,
            FollowUpUpdateRequest(completed=True),
        )

    def reopen(self, user_id: str, followup_id: str) -> FollowUpResponse:
        return self.update(
            user_id,
            followup_id,
            FollowUpUpdateRequest(completed=False),
        )

    def delete(self, user_id: str, followup_id: str) -> None:
        found = self._followups.get(user_id, followup_id)
        if not found:
            raise FollowUpNotFoundError()
        self._followups.delete(user_id, followup_id)

    def _to_response(self, data: dict[str, Any]) -> FollowUpResponse:
        return FollowUpResponse(
            id=data["id"],
            application_id=data["application_id"],
            company_id=data.get("company_id"),
            company_name=data.get("company_name"),
            job_title=data.get("job_title"),
            title=data.get("title") or "",
            scheduled_at=_ensure_aware(data["scheduled_at"]),
            completed=bool(data.get("completed")),
            completed_at=data.get("completed_at"),
            notes=data.get("notes"),
            is_overdue=_is_overdue(data),
            created_at=data.get("created_at"),
            updated_at=data.get("updated_at"),
        )
