"""Interview and follow-up reminder generation (scheduler-agnostic)."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any

from app.models.enums.interview_status import InterviewStatus
from app.models.enums.notification_type import NotificationType
from app.repositories.application_repository import ApplicationRepository
from app.repositories.followup_repository import FollowUpRepository
from app.repositories.interview_repository import InterviewRepository
from app.repositories.notification_repository import NotificationRepository
from app.services.notifications.notification_service import NotificationService


def _ensure_aware(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


class ReminderService:
    def __init__(
        self,
        application_repository: ApplicationRepository | None = None,
        interview_repository: InterviewRepository | None = None,
        followup_repository: FollowUpRepository | None = None,
        notification_service: NotificationService | None = None,
        notification_repository: NotificationRepository | None = None,
    ):
        self._apps = application_repository or ApplicationRepository()
        self._interviews = interview_repository or InterviewRepository()
        self._followups = followup_repository or FollowUpRepository()
        self._notifications = notification_repository or NotificationRepository()
        self._notifier = notification_service or NotificationService(
            notification_repository=self._notifications
        )

    def process_user(self, user_id: str, *, now: datetime | None = None) -> dict[str, int]:
        now = _ensure_aware(now or datetime.now(timezone.utc))
        prefs = self._notifications.get_preferences(user_id)
        created = {"interview": 0, "followup": 0, "overdue": 0}

        apps = {a["id"]: a for a in self._apps.list_all(user_id)}
        interviews = self._interviews.list_all_for_user(user_id, list(apps.keys()))

        if prefs.get("interview_reminders", True):
            for iv in interviews:
                if (iv.get("status") or "") != InterviewStatus.SCHEDULED.value:
                    continue
                scheduled = iv.get("scheduled_at")
                if not scheduled:
                    continue
                scheduled = _ensure_aware(scheduled)
                company = iv.get("company_name") or "Company"
                title = iv.get("title") or "Interview"
                for label, offset in (("24h", timedelta(hours=24)), ("1h", timedelta(hours=1))):
                    target = scheduled - offset
                    # Fire within a 15-minute window after target
                    if target <= now < target + timedelta(minutes=15):
                        body = (
                            f"{title} tomorrow — {company}"
                            if label == "24h"
                            else f"{title} starts in 1 hour — {company}"
                        )
                        result = self._notifier.create_and_push(
                            user_id,
                            type=NotificationType.INTERVIEW_REMINDER,
                            title="Interview reminder",
                            body=body,
                            data={"reminder_type": label},
                            related_application_id=iv.get("application_id"),
                            related_interview_id=iv.get("id"),
                            dedupe_key=f"interview_{iv['id']}_{label}",
                        )
                        if result:
                            created["interview"] += 1

        followups = self._followups.list_all(user_id)
        for fu in followups:
            if fu.get("completed"):
                continue
            scheduled = fu.get("scheduled_at")
            if not scheduled:
                continue
            scheduled = _ensure_aware(scheduled)
            company = fu.get("company_name") or "Company"
            job = fu.get("job_title") or ""
            if prefs.get("followup_reminders", True):
                if scheduled <= now < scheduled + timedelta(minutes=15):
                    result = self._notifier.create_and_push(
                        user_id,
                        type=NotificationType.FOLLOWUP_REMINDER,
                        title="Follow-up reminder",
                        body=f"{fu.get('title') or 'Follow-up'} — {company}"
                        + (f" ({job})" if job else ""),
                        related_application_id=fu.get("application_id"),
                        related_followup_id=fu.get("id"),
                        dedupe_key=f"followup_{fu['id']}_due",
                    )
                    if result:
                        created["followup"] += 1
            if prefs.get("overdue_followups", True):
                # One overdue notice the day after scheduled date (window)
                overdue_start = scheduled + timedelta(days=1)
                if overdue_start <= now < overdue_start + timedelta(hours=6):
                    result = self._notifier.create_and_push(
                        user_id,
                        type=NotificationType.FOLLOWUP_OVERDUE,
                        title="Follow-up overdue",
                        body=f"You planned to follow up with {company}.",
                        related_application_id=fu.get("application_id"),
                        related_followup_id=fu.get("id"),
                        dedupe_key=f"followup_{fu['id']}_overdue",
                    )
                    if result:
                        created["overdue"] += 1
        return created
