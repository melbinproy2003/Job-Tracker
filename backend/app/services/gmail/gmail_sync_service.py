"""Gmail synchronization, detection, and matching."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from app.core.exceptions import AppError, NotFoundError
from app.integrations.google.gmail_client import GoogleGmailClient
from app.models.enums.activity_type import ActivityType
from app.models.enums.gmail_match_status import GmailMatchStatus
from app.models.enums.notification_type import NotificationType
from app.repositories.application_repository import ApplicationRepository
from app.repositories.gmail_account_repository import GmailAccountRepository
from app.repositories.gmail_message_repository import GmailMessageRepository
from app.repositories.gmail_thread_repository import GmailThreadRepository
from app.services.activities.activity_service import ActivityService
from app.services.gmail.application_matcher import ApplicationMatcher
from app.services.gmail.email_parser import parse_gmail_message
from app.services.gmail.gmail_oauth_service import GmailOAuthService
from app.services.gmail.job_email_detector import JobEmailDetector
from app.services.notifications.notification_service import NotificationService

# In-memory sync locks (per process)
_SYNC_LOCKS: set[str] = set()


class GmailSyncService:
    def __init__(
        self,
        account_repository: GmailAccountRepository | None = None,
        thread_repository: GmailThreadRepository | None = None,
        message_repository: GmailMessageRepository | None = None,
        application_repository: ApplicationRepository | None = None,
        oauth_service: GmailOAuthService | None = None,
        detector: JobEmailDetector | None = None,
        matcher: ApplicationMatcher | None = None,
        notification_service: NotificationService | None = None,
        activity_service: ActivityService | None = None,
    ):
        self._accounts = account_repository or GmailAccountRepository()
        self._threads = thread_repository or GmailThreadRepository()
        self._messages = message_repository or GmailMessageRepository()
        self._apps = application_repository or ApplicationRepository()
        self._oauth = oauth_service or GmailOAuthService(account_repository=self._accounts)
        self._detector = detector or JobEmailDetector()
        self._matcher = matcher or ApplicationMatcher()
        self._notifier = notification_service or NotificationService()
        self._activities = activity_service or ActivityService(application_repository=self._apps)

    def sync(self, user_id: str, *, full_sync: bool = False) -> dict[str, Any]:
        lock_key = user_id
        if lock_key in _SYNC_LOCKS:
            raise AppError("Gmail sync already in progress.", code="GMAIL_SYNC_IN_PROGRESS", status_code=409)
        _SYNC_LOCKS.add(lock_key)
        try:
            return self._sync(user_id, full_sync=full_sync)
        finally:
            _SYNC_LOCKS.discard(lock_key)

    def _sync(self, user_id: str, *, full_sync: bool) -> dict[str, Any]:
        account = self._accounts.get_primary(user_id)
        if not account or not account.get("connected"):
            raise NotFoundError("No connected Gmail account.", code="GMAIL_NOT_CONNECTED")

        prefs = self._notifier._notifications.get_preferences(user_id)
        access = self._oauth.get_valid_access_token(user_id, account)
        refresh_enc = account.get("encrypted_refresh_token")
        from app.utils.encryption import decrypt_secret

        refresh = decrypt_secret(refresh_enc) if refresh_enc else None
        client = GoogleGmailClient(access, refresh)

        messages_checked = 0
        job_related_found = 0
        matches_suggested = 0
        apps = self._apps.list_all(user_id)

        query = "newer_than:90d (application OR interview OR offer OR careers OR recruiting OR hiring)"
        page_token = None
        cursor = None if full_sync else account.get("sync_cursor")
        used_history = False

        message_ids: list[str] = []
        if cursor and not full_sync:
            try:
                history = client.get_history(str(cursor))
                used_history = True
                for record in history.get("history") or []:
                    for added in record.get("messagesAdded") or []:
                        mid = (added.get("message") or {}).get("id")
                        if mid:
                            message_ids.append(mid)
                cursor = history.get("historyId") or cursor
            except Exception:
                used_history = False
                message_ids = []

        if not used_history:
            while True:
                page = client.list_message_ids(query=query, max_results=50, page_token=page_token)
                for m in page.get("messages") or []:
                    if m.get("id"):
                        message_ids.append(m["id"])
                page_token = page.get("nextPageToken")
                if not page_token:
                    break
            cursor = client.get_profile_history_id() or cursor

        for mid in message_ids[:100]:
            messages_checked += 1
            existing = self._messages.find_by_gmail_id(user_id, mid)
            if existing:
                continue
            raw = client.get_message(mid)
            parsed = parse_gmail_message(raw)
            detection = self._detector.detect(parsed)
            msg, created = self._messages.create_if_absent(
                user_id,
                mid,
                {
                    "gmail_account_id": account["id"],
                    "gmail_thread_id": parsed.get("gmail_thread_id"),
                    "from_address": parsed.get("from_address"),
                    "to_address": parsed.get("to_address"),
                    "subject": parsed.get("subject"),
                    "snippet": parsed.get("snippet"),
                    "received_at": parsed.get("received_at"),
                    "body_text": parsed.get("body_text"),
                    "is_job_related": detection["is_job_related"],
                    "detected_category": detection.get("category"),
                    "suggested_status": detection.get("suggested_status"),
                },
            )
            if not created:
                continue

            thread = self._threads.upsert_by_gmail_id(
                user_id,
                parsed.get("gmail_thread_id") or mid,
                {
                    "gmail_account_id": account["id"],
                    "subject": parsed.get("subject"),
                    "snippet": parsed.get("snippet"),
                    "participants": [
                        x for x in [parsed.get("from_address"), parsed.get("to_address")] if x
                    ],
                    "last_message_at": parsed.get("received_at"),
                    "is_job_related": detection["is_job_related"],
                    "suggested_status": detection.get("suggested_status"),
                    "interview_suggestion": detection.get("interview_suggestion"),
                },
            )

            if not detection["is_job_related"]:
                continue

            job_related_found += 1
            candidates = self._matcher.find_candidates(
                message=parsed,
                applications=apps,
                existing_thread_application_id=thread.get("application_id"),
            )
            best = self._matcher.best_match(candidates)
            update: dict[str, Any] = {}
            if best and best["confidence"] >= 40:
                update["match_status"] = GmailMatchStatus.SUGGESTED.value
                update["suggested_application_id"] = best["application_id"]
                update["match_confidence"] = best["confidence"]
                update["match_confidence_label"] = best["confidence_label"]
                if best["confidence"] >= 70 and not thread.get("application_id"):
                    # Still require confirm — only suggest
                    pass
                matches_suggested += 1
            elif not thread.get("match_status"):
                update["match_status"] = GmailMatchStatus.UNMATCHED.value

            if update:
                thread = self._threads.update(user_id, thread["id"], update)

            # Notifications + activities
            if prefs.get("gmail_notifications", True):
                company = (best or {}).get("company_name") or parsed.get("from_address") or "Sender"
                self._notifier.create_and_push(
                    user_id,
                    type=NotificationType.GMAIL_EMAIL_DETECTED,
                    title="New job-related email",
                    body=f"{company}: {parsed.get('subject') or 'Update'}",
                    data={
                        "thread_id": thread["id"],
                        "gmail_message_id": mid,
                    },
                    related_application_id=(best or {}).get("application_id")
                    or thread.get("application_id"),
                    dedupe_key=f"gmail_{mid}_detected",
                )
                if best and best["confidence"] >= 40 and prefs.get("application_suggestions", True):
                    if detection.get("suggested_status"):
                        self._notifier.create_and_push(
                            user_id,
                            type=NotificationType.APPLICATION_STATUS_SUGGESTION,
                            title="Application status suggestion",
                            body=f"{best.get('company_name')}: suggested {detection['suggested_status']}",
                            data={
                                "thread_id": thread["id"],
                                "application_id": best["application_id"],
                                "suggested_status": detection["suggested_status"],
                            },
                            related_application_id=best["application_id"],
                            dedupe_key=f"gmail_{mid}_status_suggestion",
                        )

            if best and best.get("application_id"):
                self._activities.record(
                    user_id,
                    best["application_id"],
                    type=ActivityType.GMAIL_EMAIL_RECEIVED,
                    title="Job email received",
                    description=parsed.get("subject"),
                )

        self._accounts.update(
            user_id,
            account["id"],
            {
                "last_sync_at": datetime.now(timezone.utc),
                "sync_cursor": str(cursor) if cursor else account.get("sync_cursor"),
            },
        )
        return {
            "success": True,
            "messages_checked": messages_checked,
            "job_related_found": job_related_found,
            "matches_suggested": matches_suggested,
            "last_sync_at": datetime.now(timezone.utc),
            "message": (
                f"{messages_checked} emails checked, "
                f"{job_related_found} job-related, "
                f"{matches_suggested} matches suggested"
            ),
        }
