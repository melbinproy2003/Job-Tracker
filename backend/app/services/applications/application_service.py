"""Application business logic."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Iterable

from app.core.exceptions import ApplicationNotFoundError, CompanyNotFoundError, ValidationError
from app.models.enums.activity_type import ActivityType
from app.models.enums.application_status import ApplicationStatus
from app.repositories.activity_repository import ActivityRepository
from app.repositories.application_history_repository import ApplicationHistoryRepository
from app.repositories.application_repository import ApplicationRepository
from app.repositories.company_repository import CompanyRepository
from app.repositories.followup_repository import FollowUpRepository
from app.repositories.interview_repository import InterviewRepository
from app.schemas.application import (
    ApplicationCreateRequest,
    ApplicationResponse,
    ApplicationUpdateRequest,
    CompanySummary,
)
from app.schemas.pagination import PaginatedResponse
from app.services.activities.activity_service import ActivityService
from app.utils.text import sanitize_text


def to_application_response(data: dict[str, Any]) -> ApplicationResponse:
    status_raw = data.get("status") or ApplicationStatus.APPLIED.value
    return ApplicationResponse(
        id=data["id"],
        company=CompanySummary(
            id=data.get("company_id") or "",
            name=data.get("company_name") or "",
        ),
        job_title=data.get("job_title") or "",
        job_url=data.get("job_url"),
        location=data.get("location"),
        source=data.get("source"),
        employment_type=data.get("employment_type"),
        status=ApplicationStatus(status_raw),
        applied_at=data.get("applied_at"),
        last_updated_at=data.get("last_updated_at"),
        recruiter_name=data.get("recruiter_name"),
        recruiter_email=data.get("recruiter_email"),
        salary_min=data.get("salary_min"),
        salary_max=data.get("salary_max"),
        currency=data.get("currency"),
        resume_id=data.get("resume_id"),
        cover_letter=data.get("cover_letter"),
        notes=data.get("notes"),
        created_at=data.get("created_at"),
        updated_at=data.get("updated_at"),
    )


class ApplicationService:
    def __init__(
        self,
        application_repository: ApplicationRepository | None = None,
        company_repository: CompanyRepository | None = None,
        history_repository: ApplicationHistoryRepository | None = None,
        activity_service: ActivityService | None = None,
        interview_repository: InterviewRepository | None = None,
        followup_repository: FollowUpRepository | None = None,
        activity_repository: ActivityRepository | None = None,
    ):
        self._apps = application_repository or ApplicationRepository()
        self._companies = company_repository or CompanyRepository()
        self._history = history_repository or ApplicationHistoryRepository()
        self._activities = activity_service or ActivityService(
            application_repository=self._apps
        )
        self._interviews = interview_repository or InterviewRepository()
        self._followups = followup_repository or FollowUpRepository()
        self._activity_repo = activity_repository or ActivityRepository()

    def create(self, user_id: str, payload: ApplicationCreateRequest) -> ApplicationResponse:
        company = self._companies.get(user_id, payload.company_id)
        if not company:
            raise CompanyNotFoundError()

        applied_at = payload.applied_at or datetime.now(timezone.utc)
        data = {
            "company_id": company["id"],
            "company_name": company["name"],
            "job_title": payload.job_title,
            "job_url": payload.job_url,
            "location": sanitize_text(payload.location),
            "source": sanitize_text(payload.source),
            "employment_type": sanitize_text(payload.employment_type),
            "status": payload.status.value,
            "applied_at": applied_at,
            "recruiter_name": sanitize_text(payload.recruiter_name),
            "recruiter_email": payload.recruiter_email,
            "salary_min": payload.salary_min,
            "salary_max": payload.salary_max,
            "currency": payload.currency or "INR",
            "resume_id": payload.resume_id,
            "cover_letter": sanitize_text(payload.cover_letter),
            "notes": sanitize_text(payload.notes),
        }
        created = self._apps.create(user_id, data)
        self._history.append(
            user_id,
            created["id"],
            previous_status=None,
            new_status=payload.status.value,
            note="Initial status",
        )
        self._activities.record(
            user_id,
            created["id"],
            type=ActivityType.APPLICATION_CREATED,
            title="Application created",
            description=payload.job_title,
        )
        return to_application_response(created)

    def get(self, user_id: str, application_id: str) -> ApplicationResponse:
        app = self._apps.get(user_id, application_id)
        if not app:
            raise ApplicationNotFoundError()
        return to_application_response(app)

    def list(
        self,
        user_id: str,
        *,
        status: list[str] | None = None,
        source: list[str] | None = None,
        employment_type: list[str] | None = None,
        location: str | None = None,
        search: str | None = None,
        sort_by: str = "created_at",
        sort_order: str = "desc",
        page: int = 1,
        page_size: int = 20,
    ) -> PaginatedResponse[ApplicationResponse]:
        items = self._apps.list_all(user_id)
        items = _filter_items(
            items,
            status=status,
            source=source,
            employment_type=employment_type,
            location=location,
            search=search,
        )
        items = _sort_items(items, sort_by=sort_by, sort_order=sort_order)
        total = len(items)
        page = max(page, 1)
        page_size = min(max(page_size, 1), 100)
        start = (page - 1) * page_size
        end = start + page_size
        page_items = items[start:end]
        return PaginatedResponse(
            items=[to_application_response(i) for i in page_items],
            page=page,
            page_size=page_size,
            total=total,
            has_next=end < total,
        )

    def update(
        self, user_id: str, application_id: str, payload: ApplicationUpdateRequest
    ) -> ApplicationResponse:
        app = self._apps.get(user_id, application_id)
        if not app:
            raise ApplicationNotFoundError()

        updates = payload.model_dump(exclude_unset=True)
        if "company_id" in updates and updates["company_id"]:
            company = self._companies.get(user_id, updates["company_id"])
            if not company:
                raise CompanyNotFoundError()
            updates["company_id"] = company["id"]
            updates["company_name"] = company["name"]

        for key in ("location", "source", "employment_type", "recruiter_name", "cover_letter", "notes"):
            if key in updates:
                updates[key] = sanitize_text(updates.get(key))

        updated = self._apps.update(user_id, application_id, updates)
        self._activities.record(
            user_id,
            application_id,
            type=ActivityType.APPLICATION_UPDATED,
            title="Application updated",
            description=updated.get("job_title"),
        )
        return to_application_response(updated)

    def delete(self, user_id: str, application_id: str) -> None:
        app = self._apps.get(user_id, application_id)
        if not app:
            raise ApplicationNotFoundError()
        self._history.delete_all(user_id, application_id)
        self._interviews.delete_all_for_application(user_id, application_id)
        self._activity_repo.delete_all_for_application(user_id, application_id)
        self._followups.delete_for_application(user_id, application_id)
        self._apps.delete(user_id, application_id)


def _filter_items(
    items: list[dict[str, Any]],
    *,
    status: list[str] | None,
    source: list[str] | None,
    employment_type: list[str] | None,
    location: str | None,
    search: str | None,
) -> list[dict[str, Any]]:
    result = items
    if status:
        allowed = {s.upper() for s in status}
        result = [i for i in result if (i.get("status") or "").upper() in allowed]
    if source:
        allowed = {s.lower() for s in source}
        result = [i for i in result if (i.get("source") or "").lower() in allowed]
    if employment_type:
        allowed = {s.lower() for s in employment_type}
        result = [i for i in result if (i.get("employment_type") or "").lower() in allowed]
    if location:
        loc = location.strip().lower()
        result = [i for i in result if loc in (i.get("location") or "").lower()]
    if search:
        q = search.strip().lower()
        result = [
            i
            for i in result
            if q in (i.get("company_name") or "").lower()
            or q in (i.get("job_title") or "").lower()
            or q in (i.get("location") or "").lower()
        ]
    return result


def _sort_items(
    items: list[dict[str, Any]], *, sort_by: str, sort_order: str
) -> list[dict[str, Any]]:
    reverse = sort_order.lower() != "asc"
    key = sort_by

    def sort_key(item: dict[str, Any]):
        if key == "company_name":
            return (item.get("company_name") or "").lower()
        if key == "job_title":
            return (item.get("job_title") or "").lower()
        value = item.get(key)
        if value is None:
            return datetime.min.replace(tzinfo=timezone.utc)
        return value

    try:
        return sorted(items, key=sort_key, reverse=reverse)
    except TypeError:
        return items
