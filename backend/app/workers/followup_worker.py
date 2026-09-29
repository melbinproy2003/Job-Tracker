"""Background worker for due follow-up reminders.

Delegates to ``ReminderService`` so the scheduling mechanism (cron, Cloud
Scheduler, a future Cloud Function) stays replaceable.
"""

from __future__ import annotations

import logging

from app.repositories.user_repository import UserRepository
from app.services.notifications.reminder_service import ReminderService

logger = logging.getLogger(__name__)


def run_followup_check_once(
    user_repository: UserRepository | None = None,
    reminder_service: ReminderService | None = None,
) -> dict[str, int]:
    """Generate due follow-up + overdue notifications for all users."""
    reminder = reminder_service or ReminderService()
    users_repo = user_repository or UserRepository()

    try:
        users = users_repo.list_all()
    except Exception:
        logger.exception("Could not enumerate users; follow-up run aborted.")
        return {"users": 0, "interview": 0, "followup": 0, "overdue": 0}

    totals = {"users": 0, "interview": 0, "followup": 0, "overdue": 0}
    for user in users:
        uid = user.get("id")
        if not uid:
            continue
        try:
            result = reminder.process_user(uid)
        except Exception:
            logger.exception("Follow-up check failed for a user.")
            continue
        totals["users"] += 1
        for key in ("followup", "overdue"):
            totals[key] += result.get(key, 0)
    return totals


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    print(run_followup_check_once())
