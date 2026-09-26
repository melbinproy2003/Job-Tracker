"""Dashboard aggregation service."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from app.models.enums.application_status import ApplicationStatus
from app.models.enums.interview_status import InterviewStatus
from app.repositories.application_repository import ApplicationRepository
from app.repositories.followup_repository import FollowUpRepository
from app.repositories.interview_repository import InterviewRepository
from app.schemas.dashboard import (
    DashboardRecentApplication,
    DashboardResponse,
    DashboardUpcomingEvent,
)


ACTIVE_STATUSES = {
    ApplicationStatus.SAVED.value,
    ApplicationStatus.APPLIED.value,
    ApplicationStatus.VIEWED.value,
    ApplicationStatus.SHORTLISTED.value,
    ApplicationStatus.HR_CALL.value,
    ApplicationStatus.TECHNICAL_ROUND.value,
    ApplicationStatus.INTERVIEW.value,
    ApplicationStatus.FINAL_ROUND.value,
    ApplicationStatus.NO_RESPONSE.value,
}

TERMINAL_STATUSES = {
    ApplicationStatus.REJECTED.value,
    ApplicationStatus.WITHDRAWN.value,
    ApplicationStatus.ACCEPTED.value,
}


def _ensure_aware(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


class DashboardService:
    def __init__(
        self,
        application_repository: ApplicationRepository | None = None,
        interview_repository: InterviewRepository | None = None,
        followup_repository: FollowUpRepository | None = None,
    ):
        self._apps = application_repository or ApplicationRepository()
        self._interviews = interview_repository or InterviewRepository()
        self._followups = followup_repository or FollowUpRepository()

    def get_dashboard(self, user_id: str) -> DashboardResponse:
        now = datetime.now(timezone.utc)
        apps = self._apps.list_all(user_id)
        app_ids = [a["id"] for a in apps]
        interviews = self._interviews.list_all_for_user(user_id, app_ids)
        followups = self._followups.list_all(user_id)

        status_distribution: dict[str, int] = {}
        active = 0
        offers = 0
        accepted = 0
        rejected = 0
        for app in apps:
            status = (app.get("status") or ApplicationStatus.APPLIED.value).upper()
            status_distribution[status] = status_distribution.get(status, 0) + 1
            if status in ACTIVE_STATUSES:
                active += 1
            if status == ApplicationStatus.OFFER.value:
                offers += 1
            if status == ApplicationStatus.ACCEPTED.value:
                accepted += 1
            if status == ApplicationStatus.REJECTED.value:
                rejected += 1

        upcoming_interviews = 0
        completed_interviews = 0
        for iv in interviews:
            status = iv.get("status") or InterviewStatus.SCHEDULED.value
            if status == InterviewStatus.COMPLETED.value:
                completed_interviews += 1
            scheduled = iv.get("scheduled_at")
            if (
                status == InterviewStatus.SCHEDULED.value
                and scheduled
                and _ensure_aware(scheduled) >= now
            ):
                upcoming_interviews += 1

        pending_followups = 0
        overdue_followups = 0
        completed_followups = 0
        for fu in followups:
            if fu.get("completed"):
                completed_followups += 1
                continue
            pending_followups += 1
            scheduled = fu.get("scheduled_at")
            if scheduled and _ensure_aware(scheduled) < now:
                overdue_followups += 1

        recent = sorted(
            apps,
            key=lambda a: a.get("updated_at") or a.get("created_at") or datetime.min.replace(tzinfo=timezone.utc),
            reverse=True,
        )[:5]
        recent_applications = [
            DashboardRecentApplication(
                id=a["id"],
                company_name=a.get("company_name") or "",
                job_title=a.get("job_title") or "",
                status=a.get("status") or ApplicationStatus.APPLIED.value,
                updated_at=a.get("updated_at"),
            )
            for a in recent
        ]

        upcoming_events: list[DashboardUpcomingEvent] = []
        for iv in interviews:
            status = iv.get("status") or InterviewStatus.SCHEDULED.value
            scheduled = iv.get("scheduled_at")
            if status != InterviewStatus.SCHEDULED.value or not scheduled:
                continue
            if _ensure_aware(scheduled) < now:
                continue
            upcoming_events.append(
                DashboardUpcomingEvent(
                    id=iv["id"],
                    kind="interview",
                    title=iv.get("title") or "Interview",
                    company_name=iv.get("company_name"),
                    job_title=iv.get("job_title"),
                    scheduled_at=_ensure_aware(scheduled),
                    application_id=iv.get("application_id"),
                )
            )
        for fu in followups:
            if fu.get("completed"):
                continue
            scheduled = fu.get("scheduled_at")
            if not scheduled or _ensure_aware(scheduled) < now:
                continue
            upcoming_events.append(
                DashboardUpcomingEvent(
                    id=fu["id"],
                    kind="followup",
                    title=fu.get("title") or "Follow-up",
                    company_name=fu.get("company_name"),
                    job_title=fu.get("job_title"),
                    scheduled_at=_ensure_aware(scheduled),
                    application_id=fu.get("application_id"),
                )
            )
        upcoming_events.sort(key=lambda e: e.scheduled_at)

        return DashboardResponse(
            total_applications=len(apps),
            active_applications=active,
            interviews=len(interviews),
            upcoming_interviews=upcoming_interviews,
            completed_interviews=completed_interviews,
            pending_followups=pending_followups,
            overdue_followups=overdue_followups,
            completed_followups=completed_followups,
            offers=offers,
            accepted=accepted,
            rejected=rejected,
            followups_due=pending_followups,
            status_distribution=status_distribution,
            recent_applications=recent_applications,
            upcoming_events=upcoming_events[:10],
        )
