"""Interview business logic."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any

from app.core.exceptions import (
    ApplicationNotFoundError,
    InterviewConflictError,
    InterviewNotFoundError,
    InvalidInterviewError,
)
from app.models.enums.activity_type import ActivityType
from app.models.enums.interview_status import InterviewStatus
from app.models.enums.interview_type import InterviewType
from app.repositories.application_repository import ApplicationRepository
from app.repositories.interview_repository import InterviewRepository
from app.schemas.interview import InterviewCreateRequest, InterviewResponse, InterviewUpdateRequest
from app.services.activities.activity_service import ActivityService
from app.utils.text import sanitize_text


_TYPE_LABELS = {
    InterviewType.PHONE_SCREEN: "Phone Screen",
    InterviewType.HR_INTERVIEW: "HR Interview",
    InterviewType.TECHNICAL_INTERVIEW: "Technical Interview",
    InterviewType.CODING_TEST: "Coding Test",
    InterviewType.SYSTEM_DESIGN: "System Design",
    InterviewType.MANAGER_INTERVIEW: "Manager Interview",
    InterviewType.FINAL_INTERVIEW: "Final Interview",
    InterviewType.OTHER: "Other",
}


def interview_type_label(t: InterviewType | str) -> str:
    if isinstance(t, str):
        t = InterviewType(t)
    return _TYPE_LABELS.get(t, t.value.replace("_", " ").title())


def _ensure_aware(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def _overlaps(start_a: datetime, dur_a: int, start_b: datetime, dur_b: int) -> bool:
    end_a = start_a + timedelta(minutes=dur_a)
    end_b = start_b + timedelta(minutes=dur_b)
    return start_a < end_b and start_b < end_a


class InterviewService:
    def __init__(
        self,
        interview_repository: InterviewRepository | None = None,
        application_repository: ApplicationRepository | None = None,
        activity_service: ActivityService | None = None,
    ):
        self._interviews = interview_repository or InterviewRepository()
        self._apps = application_repository or ApplicationRepository()
        self._activities = activity_service or ActivityService(
            application_repository=self._apps
        )

    def _app_ids(self, user_id: str) -> list[str]:
        return [a["id"] for a in self._apps.list_all(user_id)]

    def _require_app(self, user_id: str, application_id: str) -> dict[str, Any]:
        app = self._apps.get(user_id, application_id)
        if not app:
            raise ApplicationNotFoundError()
        return app

    def _find_overlaps(
        self,
        user_id: str,
        scheduled_at: datetime,
        duration_minutes: int,
        *,
        exclude_id: str | None = None,
    ) -> list[dict[str, Any]]:
        start = _ensure_aware(scheduled_at)
        duration = duration_minutes or 60
        overlaps: list[dict[str, Any]] = []
        for item in self._interviews.list_all_for_user(user_id, self._app_ids(user_id)):
            if exclude_id and item.get("id") == exclude_id:
                continue
            status = item.get("status") or InterviewStatus.SCHEDULED.value
            if status in (InterviewStatus.CANCELLED.value, InterviewStatus.NO_SHOW.value):
                continue
            other_start = item.get("scheduled_at")
            if other_start is None:
                continue
            other_start = _ensure_aware(other_start)
            other_dur = int(item.get("duration_minutes") or 60)
            if _overlaps(start, duration, other_start, other_dur):
                overlaps.append(item)
        return overlaps

    def create(
        self, user_id: str, application_id: str, payload: InterviewCreateRequest
    ) -> InterviewResponse:
        app = self._require_app(user_id, application_id)
        scheduled_at = _ensure_aware(payload.scheduled_at)
        duration = payload.duration_minutes or 60

        overlaps = self._find_overlaps(user_id, scheduled_at, duration)
        if overlaps and not payload.force:
            raise InterviewConflictError(
                "You already have an interview scheduled during this time."
            )

        title = sanitize_text(payload.title) or interview_type_label(payload.type)
        data = {
            "company_id": app.get("company_id"),
            "company_name": app.get("company_name"),
            "job_title": app.get("job_title"),
            "type": payload.type.value,
            "title": title,
            "scheduled_at": scheduled_at,
            "duration_minutes": duration,
            "meeting_url": payload.meeting_url,
            "location": sanitize_text(payload.location),
            "interviewer_name": sanitize_text(payload.interviewer_name),
            "interviewer_email": payload.interviewer_email,
            "notes": sanitize_text(payload.notes),
            "status": payload.status.value,
        }
        created = self._interviews.create(user_id, application_id, data)
        self._activities.record(
            user_id,
            application_id,
            type=ActivityType.INTERVIEW_CREATED,
            title="Interview scheduled",
            description=title,
        )
        return self._to_response(created)

    def list_for_application(self, user_id: str, application_id: str) -> list[InterviewResponse]:
        self._require_app(user_id, application_id)
        rows = self._interviews.list_for_application(user_id, application_id)
        return [self._to_response(r) for r in rows]

    def list(
        self,
        user_id: str,
        *,
        status: str | None = None,
        from_date: datetime | None = None,
        to_date: datetime | None = None,
        application_id: str | None = None,
    ) -> list[InterviewResponse]:
        if application_id:
            self._require_app(user_id, application_id)
            rows = self._interviews.list_for_application(user_id, application_id)
        else:
            rows = self._interviews.list_all_for_user(user_id, self._app_ids(user_id))

        if status:
            rows = [r for r in rows if (r.get("status") or "").upper() == status.upper()]
        if from_date is not None:
            start = _ensure_aware(from_date)
            rows = [r for r in rows if r.get("scheduled_at") and _ensure_aware(r["scheduled_at"]) >= start]
        if to_date is not None:
            end = _ensure_aware(to_date)
            # inclusive end-of-day if date-only midnight
            rows = [r for r in rows if r.get("scheduled_at") and _ensure_aware(r["scheduled_at"]) <= end]

        rows.sort(key=lambda x: _ensure_aware(x["scheduled_at"]) if x.get("scheduled_at") else datetime.min.replace(tzinfo=timezone.utc))
        return [self._to_response(r) for r in rows]

    def get(self, user_id: str, interview_id: str) -> InterviewResponse:
        found = self._interviews.find_by_id(user_id, interview_id, self._app_ids(user_id))
        if not found:
            raise InterviewNotFoundError()
        return self._to_response(found)

    def update(self, user_id: str, interview_id: str, payload: InterviewUpdateRequest) -> InterviewResponse:
        found = self._interviews.find_by_id(user_id, interview_id, self._app_ids(user_id))
        if not found:
            raise InterviewNotFoundError()

        application_id = found["application_id"]
        updates = payload.model_dump(exclude_unset=True, exclude={"force"})
        if "type" in updates and updates["type"] is not None:
            updates["type"] = updates["type"].value if hasattr(updates["type"], "value") else updates["type"]
        if "status" in updates and updates["status"] is not None:
            updates["status"] = updates["status"].value if hasattr(updates["status"], "value") else updates["status"]
        if "scheduled_at" in updates and updates["scheduled_at"] is not None:
            updates["scheduled_at"] = _ensure_aware(updates["scheduled_at"])
        for key in ("title", "location", "interviewer_name", "notes"):
            if key in updates:
                updates[key] = sanitize_text(updates.get(key))

        scheduled_at = updates.get("scheduled_at") or found.get("scheduled_at")
        duration = updates.get("duration_minutes")
        if duration is None:
            duration = found.get("duration_minutes") or 60
        if scheduled_at is not None:
            overlaps = self._find_overlaps(
                user_id, _ensure_aware(scheduled_at), int(duration), exclude_id=interview_id
            )
            if overlaps and not payload.force:
                raise InterviewConflictError(
                    "You already have an interview scheduled during this time."
                )

        previous_status = found.get("status")
        updated = self._interviews.update(user_id, application_id, interview_id, updates)

        new_status = updated.get("status")
        if (
            new_status == InterviewStatus.COMPLETED.value
            and previous_status != InterviewStatus.COMPLETED.value
        ):
            self._activities.record(
                user_id,
                application_id,
                type=ActivityType.INTERVIEW_COMPLETED,
                title="Interview completed",
                description=updated.get("title"),
            )
        return self._to_response(updated)

    def delete(self, user_id: str, interview_id: str) -> None:
        found = self._interviews.find_by_id(user_id, interview_id, self._app_ids(user_id))
        if not found:
            raise InterviewNotFoundError()
        self._interviews.delete(user_id, found["application_id"], interview_id)

    def _to_response(self, data: dict[str, Any]) -> InterviewResponse:
        type_raw = data.get("type") or InterviewType.OTHER.value
        status_raw = data.get("status") or InterviewStatus.SCHEDULED.value
        try:
            itype = InterviewType(type_raw)
        except ValueError as exc:
            raise InvalidInterviewError(f"Unknown interview type: {type_raw}") from exc
        try:
            istatus = InterviewStatus(status_raw)
        except ValueError as exc:
            raise InvalidInterviewError(f"Unknown interview status: {status_raw}") from exc
        return InterviewResponse(
            id=data["id"],
            application_id=data["application_id"],
            company_id=data.get("company_id"),
            company_name=data.get("company_name"),
            job_title=data.get("job_title"),
            type=itype,
            title=data.get("title"),
            scheduled_at=_ensure_aware(data["scheduled_at"]),
            duration_minutes=data.get("duration_minutes"),
            meeting_url=data.get("meeting_url"),
            location=data.get("location"),
            interviewer_name=data.get("interviewer_name"),
            interviewer_email=data.get("interviewer_email"),
            notes=data.get("notes"),
            status=istatus,
            created_at=data.get("created_at"),
            updated_at=data.get("updated_at"),
        )
