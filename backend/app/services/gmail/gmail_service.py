"""Gmail account management, listing, and match actions."""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any

from app.core.exceptions import (
    AppError,
    ApplicationNotFoundError,
    InterviewConflictError,
    NotFoundError,
    ValidationError,
)
from app.models.enums.activity_type import ActivityType
from app.models.enums.application_status import ApplicationStatus
from app.models.enums.gmail_match_status import GmailMatchStatus
from app.models.enums.interview_type import InterviewType
from app.repositories.application_repository import ApplicationRepository
from app.repositories.gmail_account_repository import GmailAccountRepository
from app.repositories.gmail_message_repository import GmailMessageRepository
from app.repositories.gmail_thread_repository import GmailThreadRepository
from app.schemas.application import ApplicationStatusUpdateRequest
from app.schemas.gmail import (
    ApplicationDraftFromEmail,
    GmailAccountResponse,
    GmailMatchConfirmRequest,
    GmailMatchResponse,
    GmailMessageResponse,
    GmailThreadResponse,
    GmailTimelineEvent,
    InterviewSuggestion,
    MatchCandidate,
)
from app.schemas.interview import InterviewCreateRequest
from app.services.activities.activity_service import ActivityService
from app.services.applications.application_status_service import ApplicationStatusService
from app.services.gmail.application_matcher import ApplicationMatcher
from app.services.gmail.gmail_oauth_service import GmailOAuthService
from app.services.gmail.gmail_sync_service import GmailSyncService
from app.services.interviews.interview_service import InterviewService

logger = logging.getLogger(__name__)


def _action_key(kind: str, application_id: str, extra: str = "") -> str:
    base = f"{kind}:{application_id}"
    return f"{base}:{extra}" if extra else base


def _parse_interview_suggestion(raw: Any) -> InterviewSuggestion | None:
    if not raw:
        return None
    if isinstance(raw, InterviewSuggestion):
        return raw
    if not isinstance(raw, dict):
        return None
    data = dict(raw)
    # Normalize type aliases
    if data.get("interview_type") and not data.get("type"):
        data["type"] = data["interview_type"]
    if data.get("type") and not data.get("interview_type"):
        data["interview_type"] = data["type"]
    scheduled = data.get("scheduled_at")
    if isinstance(scheduled, str):
        try:
            data["scheduled_at"] = datetime.fromisoformat(scheduled.replace("Z", "+00:00"))
        except ValueError:
            data["scheduled_at"] = None
    try:
        return InterviewSuggestion.model_validate(data)
    except Exception:
        raw_scheduled = data.get("scheduled_at")
        scheduled_at = raw_scheduled if isinstance(raw_scheduled, datetime) else None
        return InterviewSuggestion(
            title=data.get("title"),
            scheduled_at=scheduled_at,
            duration_minutes=data.get("duration_minutes"),
            meeting_url=data.get("meeting_url"),
            location=data.get("location"),
            interviewer_name=data.get("interviewer_name"),
            interviewer_email=data.get("interviewer_email"),
            interview_type=data.get("interview_type") or data.get("type"),
            type=data.get("type") or data.get("interview_type"),
            confidence=data.get("confidence"),
        )


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
        matcher: ApplicationMatcher | None = None,
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
        self._status = status_service or ApplicationStatusService(application_repository=self._apps)
        self._interviews = interview_service or InterviewService(application_repository=self._apps)
        self._activities = activity_service or ActivityService(application_repository=self._apps)
        self._matcher = matcher or ApplicationMatcher()

    def start_connect(self, user_id: str) -> str:
        return self._oauth.build_authorization_url(user_id)

    def handle_callback(
        self,
        code: str | None,
        state: str | None,
        *,
        oauth_error: str | None = None,
    ) -> str:
        try:
            result = self._oauth.handle_callback(code=code, state=state, oauth_error=oauth_error)
            return self._oauth.frontend_redirect(success=True, email=result["email"])
        except ValidationError as exc:
            logger.info("Gmail OAuth validation failed: %s", exc.code)
            return self._oauth.frontend_redirect(success=False, error=exc.code.lower())
        except AppError as exc:
            logger.warning("Gmail OAuth failed: %s", exc.code)
            return self._oauth.frontend_redirect(success=False, error=exc.code.lower())
        except Exception as exc:
            logger.exception("Gmail OAuth unexpected error: %s", type(exc).__name__)
            return self._oauth.frontend_redirect(success=False, error="oauth_failed")

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
            self._thread_response(user_id, t)
            for t in self._threads.list(user_id, application_id=application_id)
        ]

    def get_thread(self, user_id: str, thread_id: str) -> GmailThreadResponse:
        thread = self._threads.get(user_id, thread_id)
        if not thread:
            raise NotFoundError("Gmail thread not found.", code="GMAIL_THREAD_NOT_FOUND")
        return self._thread_response(user_id, thread, include_candidates=True)

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
            detection_confidence=msg.get("detection_confidence"),
            matched_signals=list(msg.get("matched_signals") or []),
        )

    def application_timeline(self, user_id: str, application_id: str) -> list[GmailTimelineEvent]:
        app = self._apps.get(user_id, application_id)
        if not app:
            raise ApplicationNotFoundError()
        events: list[GmailTimelineEvent] = []
        for t in self._threads.list(user_id, application_id=application_id):
            category = t.get("detected_category") or "EMAIL"
            title = t.get("subject") or category.replace("_", " ").title()
            events.append(
                GmailTimelineEvent(
                    id=t["id"],
                    kind="email",
                    title=title,
                    occurred_at=t.get("last_message_at"),
                    category=category,
                    thread_id=t["id"],
                )
            )
        events.sort(
            key=lambda e: e.occurred_at or datetime.min.replace(tzinfo=timezone.utc),
            reverse=True,
        )
        return events

    def confirm_match(
        self, user_id: str, thread_id: str, payload: GmailMatchConfirmRequest
    ) -> GmailMatchResponse:
        thread = self._threads.get(user_id, thread_id)
        if not thread:
            raise NotFoundError("Gmail thread not found.", code="GMAIL_THREAD_NOT_FOUND")
        app = self._apps.get(user_id, payload.application_id)
        if not app:
            raise ApplicationNotFoundError()

        applied_actions = set(thread.get("applied_actions") or [])
        link_key = _action_key("link", payload.application_id)
        matched = thread.get("match_status") == GmailMatchStatus.MATCHED.value
        already = link_key in applied_actions and matched

        applied = False
        interview_created = False
        interview_id = None
        interview_conflict = False
        conflict_message = None
        new_actions = set(applied_actions)

        if link_key not in applied_actions:
            self._threads.update(
                user_id,
                thread_id,
                {
                    "application_id": payload.application_id,
                    "match_status": GmailMatchStatus.MATCHED.value,
                    "suggested_application_id": payload.application_id,
                },
            )
            gmail_tid = thread.get("gmail_thread_id")
            for msg in self._messages.list(user_id, thread_id=gmail_tid):
                self._messages.update(
                    user_id,
                    msg["id"],
                    {"application_id": payload.application_id},
                )
            self._activities.record(
                user_id,
                payload.application_id,
                type=ActivityType.GMAIL_EMAIL_MATCHED,
                title="Email linked to application",
                description=thread.get("subject"),
            )
            new_actions.add(link_key)
        else:
            # Ensure link fields stay consistent on repeat confirm.
            self._threads.update(
                user_id,
                thread_id,
                {
                    "application_id": payload.application_id,
                    "match_status": GmailMatchStatus.MATCHED.value,
                },
            )

        if payload.confirm_status is not None:
            status_key = _action_key("status", payload.application_id, payload.confirm_status.value)
            if status_key not in applied_actions:
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
                new_actions.add(status_key)

        if payload.create_interview and payload.interview:
            iv = payload.interview
            scheduled = iv.get("scheduled_at")
            if not scheduled:
                raise ValidationError(
                    "Interview scheduled_at is required.", code="INVALID_INTERVIEW"
                )
            if isinstance(scheduled, str):
                scheduled = datetime.fromisoformat(scheduled.replace("Z", "+00:00"))
            sched_key = scheduled.astimezone(timezone.utc).strftime("%Y%m%dT%H%M")
            itype_raw = iv.get("interview_type") or iv.get("type") or InterviewType.OTHER.value
            interview_key = _action_key(
                "interview", payload.application_id, f"{itype_raw}:{sched_key}"
            )

            if interview_key in applied_actions:
                interview_created = False
                already = True
            else:
                itype = InterviewType(itype_raw)
                try:
                    created = self._interviews.create(
                        user_id,
                        payload.application_id,
                        InterviewCreateRequest(
                            type=itype,
                            title=iv.get("title"),
                            scheduled_at=scheduled,
                            duration_minutes=iv.get("duration_minutes") or 60,
                            meeting_url=iv.get("meeting_url"),
                            location=iv.get("location"),
                            interviewer_name=iv.get("interviewer_name"),
                            interviewer_email=iv.get("interviewer_email"),
                            notes=iv.get("notes"),
                            force=bool(payload.force_interview),
                        ),
                    )
                    interview_created = True
                    interview_id = getattr(created, "id", None) or (
                        created.get("id") if isinstance(created, dict) else None
                    )
                    self._activities.record(
                        user_id,
                        payload.application_id,
                        type=ActivityType.INTERVIEW_SUGGESTION,
                        title="Interview created from email",
                        description=iv.get("title") or thread.get("subject"),
                    )
                    new_actions.add(interview_key)
                except InterviewConflictError as exc:
                    if payload.force_interview:
                        raise
                    interview_conflict = True
                    conflict_message = str(exc.message) if hasattr(exc, "message") else str(exc)

        if new_actions != applied_actions:
            self._threads.update(
                user_id,
                thread_id,
                {"applied_actions": sorted(new_actions)},
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
            already_applied=already and not applied and not interview_created,
            interview_conflict=interview_conflict,
            conflict_message=conflict_message,
            interview_id=interview_id,
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

    def unlink_match(self, user_id: str, thread_id: str) -> GmailMatchResponse:
        thread = self._threads.get(user_id, thread_id)
        if not thread:
            raise NotFoundError("Gmail thread not found.", code="GMAIL_THREAD_NOT_FOUND")
        self._threads.update(
            user_id,
            thread_id,
            {
                "application_id": None,
                "match_status": GmailMatchStatus.UNMATCHED.value,
            },
        )
        for msg in self._messages.list(user_id, thread_id=thread.get("gmail_thread_id")):
            self._messages.update(user_id, msg["id"], {"application_id": None})
        return GmailMatchResponse(
            thread_id=thread_id,
            application_id=None,
            match_status=GmailMatchStatus.UNMATCHED,
            applied=False,
            interview_created=False,
        )

    def _thread_response(
        self, user_id: str, t: dict[str, Any], *, include_candidates: bool = False
    ) -> GmailThreadResponse:
        status_raw = t.get("match_status") or GmailMatchStatus.UNMATCHED.value
        suggested = t.get("suggested_status")
        interview = _parse_interview_suggestion(t.get("interview_suggestion"))
        candidates_raw = list(t.get("match_candidates") or [])
        draft_raw = t.get("application_draft")

        if include_candidates and not candidates_raw and t.get("is_job_related"):
            # Live recompute for detail view.
            msgs = self._messages.list(user_id, thread_id=t.get("gmail_thread_id"))
            sample = (
                msgs[0]
                if msgs
                else {
                    "subject": t.get("subject"),
                    "snippet": t.get("snippet"),
                    "from_address": (t.get("participants") or [None])[0],
                }
            )
            apps = self._apps.list_all(user_id)
            candidates_raw = self._matcher.find_candidates(
                message=sample,
                applications=apps,
                existing_thread_application_id=t.get("application_id"),
            )
            if not draft_raw and not candidates_raw:
                draft_raw = self._matcher.build_application_draft(sample)

        candidates = [
            MatchCandidate(
                application_id=c["application_id"],
                company_name=c.get("company_name"),
                job_title=c.get("job_title"),
                score=c.get("score"),
                confidence=int(c.get("confidence") or 0),
                confidence_label=c.get("confidence_label"),
                confidence_band=c.get("confidence_band"),
                reasons=list(c.get("reasons") or []),
            )
            for c in candidates_raw
        ]

        draft: ApplicationDraftFromEmail | dict[str, Any] | None = None
        if isinstance(draft_raw, dict):
            try:
                draft = ApplicationDraftFromEmail.model_validate(draft_raw)
            except Exception:
                draft = draft_raw

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
            detected_category=t.get("detected_category"),
            detection_confidence=t.get("detection_confidence"),
            matched_signals=list(t.get("matched_signals") or []),
            suggested_status=ApplicationStatus(suggested) if suggested else None,
            match_confidence=t.get("match_confidence"),
            match_confidence_label=t.get("match_confidence_label"),
            interview_suggestion=interview,
            match_candidates=candidates,
            application_draft=draft,
        )
