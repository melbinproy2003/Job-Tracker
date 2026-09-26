"""Gmail account management, listing, and match actions."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from app.core.exceptions import ApplicationNotFoundError, NotFoundError, ValidationError
from app.models.enums.activity_type import ActivityType
from app.models.enums.application_status import ApplicationStatus
from app.models.enums.gmail_match_status import GmailMatchStatus
from app.models.enums.interview_type import InterviewType
from app.repositories.application_repository import ApplicationRepository
from app.repositories.gmail_account_repository import GmailAccountRepository
from app.repositories.gmail_message_repository import GmailMessageRepository
from app.repositories.gmail_thread_repository import GmailThreadRepository
from app.schemas.gmail import (
    GmailAccountResponse,
    GmailMatchConfirmRequest,
    GmailMatchResponse,
    GmailMessageResponse,
    GmailThreadResponse,
)
from app.schemas.interview import InterviewCreateRequest
from app.services.activities.activity_service import ActivityService
from app.services.applications.application_status_service import ApplicationStatusService
from app.services.gmail.gmail_oauth_service import GmailOAuthService
from app.services.gmail.gmail_sync_service import GmailSyncService
from app.services.interviews.interview_service import InterviewService
from app.schemas.application import ApplicationStatusUpdateRequest


class GmailService:
    def __init__(
        self,
        account_repository: GmailAccountRepository | None = None,
        thread_repository: GmailThreadRepository | None = None,
        message_repository: GmailMessageRepository | None = None,
        application_repository: ApplicationRepository | None = None,
        oauth_service: GmailOAuthService | None = None,
        sync_service: GmailSyncService | None = None,
        status_service: ApplicationStatusService | None = None,
        interview_service: InterviewService | None = None,
        activity_service: ActivityService | None = None,
    ):
        self._accounts = account_repository or GmailAccountRepository()
        self._threads = thread_repository or GmailThreadRepository()
        self._messages = message_repository or GmailMessageRepository()
        self._apps = application_repository or ApplicationRepository()
        self._oauth = oauth_service or GmailOAuthService(account_repository=self._accounts)
        self._sync = sync_service or GmailSyncService(
            account_repository=self._accounts,
            thread_repository=self._threads,
            message_repository=self._messages,
            application_repository=self._apps,
            oauth_service=self._oauth,
        )
        self._status = status_service or ApplicationStatusService(
            application_repository=self._apps
        )
        self._interviews = interview_service or InterviewService(
            application_repository=self._apps
        )
        self._activities = activity_service or ActivityService(
            application_repository=self._apps
        )

    def start_connect(self, user_id: str) -> str:
        return self._oauth.build_authorization_url(user_id)

    def handle_callback(self, code: str | None, state: str | None) -> str:
        try:
            result = self._oauth.handle_callback(code=code, state=state)
            return self._oauth.frontend_redirect(success=True, email=result["email"])
        except Exception as exc:
            return self._oauth.frontend_redirect(success=False, error=str(exc)[:120])

    def list_accounts(self, user_id: str) -> list[GmailAccountResponse]:
        items = []
        for a in self._accounts.list(user_id):
            items.append(
                GmailAccountResponse(
                    id=a["id"],
                    email=a.get("email") or "",
                    connected=bool(a.get("connected")),
                    last_sync_at=a.get("last_sync_at"),
                    scopes=list(a.get("scopes") or []),
                )
            )
        return items

    def disconnect(self, user_id: str, account_id: str) -> None:
        account = self._accounts.get(user_id, account_id)
        if not account:
            raise NotFoundError("Gmail account not found.", code="GMAIL_ACCOUNT_NOT_FOUND")
        self._accounts.delete_credentials(user_id, account_id)

    def sync(self, user_id: str, *, full_sync: bool = False):
        return self._sync.sync(user_id, full_sync=full_sync)

    def list_threads(
        self, user_id: str, *, application_id: str | None = None
    ) -> list[GmailThreadResponse]:
        return [
            self._thread_response(t)
            for t in self._threads.list(user_id, application_id=application_id)
        ]

    def get_thread(self, user_id: str, thread_id: str) -> GmailThreadResponse:
        thread = self._threads.get(user_id, thread_id)
        if not thread:
            raise NotFoundError("Gmail thread not found.", code="GMAIL_THREAD_NOT_FOUND")
        return self._thread_response(thread)

    def get_message(self, user_id: str, message_id: str) -> GmailMessageResponse:
        msg = self._messages.get(user_id, message_id)
        if not msg:
            raise NotFoundError("Gmail message not found.", code="GMAIL_MESSAGE_NOT_FOUND")
        return GmailMessageResponse(
            id=msg["id"],
            gmail_message_id=msg.get("gmail_message_id") or "",
            gmail_thread_id=msg.get("gmail_thread_id") or "",
            from_address=msg.get("from_address"),
            to_address=msg.get("to_address"),
            subject=msg.get("subject"),
            snippet=msg.get("snippet"),
            received_at=msg.get("received_at"),
            body_text=msg.get("body_text"),
            application_id=msg.get("application_id"),
            is_job_related=bool(msg.get("is_job_related")),
            detected_category=msg.get("detected_category"),
        )

    def confirm_match(
        self, user_id: str, thread_id: str, payload: GmailMatchConfirmRequest
    ) -> GmailMatchResponse:
        thread = self._threads.get(user_id, thread_id)
        if not thread:
            raise NotFoundError("Gmail thread not found.", code="GMAIL_THREAD_NOT_FOUND")
        app = self._apps.get(user_id, payload.application_id)
        if not app:
            raise ApplicationNotFoundError()

        self._threads.update(
            user_id,
            thread_id,
            {
                "application_id": payload.application_id,
                "match_status": GmailMatchStatus.MATCHED.value,
                "suggested_application_id": payload.application_id,
            },
        )
        # Link messages
        for msg in self._messages.list(user_id, thread_id=thread.get("gmail_thread_id")):
            self._messages.update(user_id, msg["id"], {"application_id": payload.application_id})

        self._activities.record(
            user_id,
            payload.application_id,
            type=ActivityType.GMAIL_EMAIL_MATCHED,
            title="Email linked to application",
            description=thread.get("subject"),
        )

        applied = False
        if payload.confirm_status is not None:
            self._status.change_status(
                user_id,
                payload.application_id,
                ApplicationStatusUpdateRequest(status=payload.confirm_status),
            )
            applied = True
            self._activities.record(
                user_id,
                payload.application_id,
                type=ActivityType.GMAIL_STATUS_SUGGESTION,
                title="Status updated from email",
                description=payload.confirm_status.value,
            )

        interview_created = False
        if payload.create_interview and payload.interview:
            iv = payload.interview
            scheduled = iv.get("scheduled_at")
            if not scheduled:
                raise ValidationError("Interview scheduled_at is required.", code="INVALID_INTERVIEW")
            if isinstance(scheduled, str):
                scheduled = datetime.fromisoformat(scheduled.replace("Z", "+00:00"))
            itype = InterviewType(iv.get("type") or InterviewType.OTHER.value)
            self._interviews.create(
                user_id,
                payload.application_id,
                InterviewCreateRequest(
                    type=itype,
                    title=iv.get("title"),
                    scheduled_at=scheduled,
                    duration_minutes=iv.get("duration_minutes") or 60,
                    meeting_url=iv.get("meeting_url"),
                    interviewer_name=iv.get("interviewer_name"),
                    notes=iv.get("notes"),
                    force=True,
                ),
            )
            interview_created = True
            self._activities.record(
                user_id,
                payload.application_id,
                type=ActivityType.INTERVIEW_SUGGESTION,
                title="Interview created from email",
                description=iv.get("title") or thread.get("subject"),
            )

        suggested = thread.get("suggested_status")
        suggested_status = ApplicationStatus(suggested) if suggested else None
        return GmailMatchResponse(
            thread_id=thread_id,
            application_id=payload.application_id,
            match_status=GmailMatchStatus.MATCHED,
            suggested_status=suggested_status,
            applied=applied,
            interview_created=interview_created,
        )

    def ignore_match(self, user_id: str, thread_id: str) -> GmailMatchResponse:
        thread = self._threads.get(user_id, thread_id)
        if not thread:
            raise NotFoundError("Gmail thread not found.", code="GMAIL_THREAD_NOT_FOUND")
        self._threads.update(
            user_id,
            thread_id,
            {"match_status": GmailMatchStatus.IGNORED.value},
        )
        return GmailMatchResponse(
            thread_id=thread_id,
            application_id=thread.get("application_id"),
            match_status=GmailMatchStatus.IGNORED,
            applied=False,
            interview_created=False,
        )

    def _thread_response(self, t: dict[str, Any]) -> GmailThreadResponse:
        status_raw = t.get("match_status") or GmailMatchStatus.UNMATCHED.value
        suggested = t.get("suggested_status")
        return GmailThreadResponse(
            id=t["id"],
            gmail_thread_id=t.get("gmail_thread_id") or "",
            subject=t.get("subject"),
            snippet=t.get("snippet"),
            participants=list(t.get("participants") or []),
            last_message_at=t.get("last_message_at"),
            application_id=t.get("application_id") or t.get("suggested_application_id"),
            match_status=GmailMatchStatus(status_raw),
            is_job_related=bool(t.get("is_job_related")),
            suggested_status=ApplicationStatus(suggested) if suggested else None,
            match_confidence=t.get("match_confidence"),
            match_confidence_label=t.get("match_confidence_label"),
            interview_suggestion=t.get("interview_suggestion"),
        )
