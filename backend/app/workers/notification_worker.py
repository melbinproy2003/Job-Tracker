"""Runnable reminder dispatcher (cron-friendly).

Runs on a host cron/Cloud Scheduler tick. Business logic lives entirely in
``ReminderService`` so the scheduling mechanism stays replaceable.
"""

from __future__ import annotations

import logging

from app.repositories.user_repository import UserRepository
from app.services.notifications.reminder_service import ReminderService

logger = logging.getLogger(__name__)


def run_notification_dispatch_once(
    user_repository: UserRepository | None = None,
    reminder_service: ReminderService | None = None,
) -> dict[str, int]:
    """Process interview/follow-up reminders for all users."""
    reminder = reminder_service or ReminderService()
    users_repo = user_repository or UserRepository()

    try:
        users = users_repo.list_all()
    except Exception:
        # Never let a Firestore hiccup kill the whole run silently.
        logger.exception("Could not enumerate users; reminder run aborted.")
        return {"users": 0, "interview": 0, "followup": 0, "overdue": 0}

    totals = {"users": 0, "interview": 0, "followup": 0, "overdue": 0}
    for user in users:
        uid = user.get("id")
        if not uid:
            continue
        try:
            result = reminder.process_user(uid)
        except Exception:
            # One user's bad data must not abort the other users' reminders.
            logger.exception("Reminder processing failed for a user.")
            continue
        totals["users"] += 1
        for key in ("interview", "followup", "overdue"):
            totals[key] += result.get(key, 0)
    return totals


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    print(run_notification_dispatch_once())
