"""Phase 4/5 cross-cutting contract tests.

These cover the two guarantees that are easiest to regress silently and that
the frontend depends on:

1. The Gmail push payload uses ``thread_id`` (the key the Flutter router
   resolves), not ``gmail_thread_id``.
2. Nothing is mutated without an explicit opt-in: linking is safe, but a
   status change and an interview creation each require the caller to ask.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any
from unittest.mock import MagicMock

import pytest

from app.core.config import get_settings
from app.models.enums.gmail_match_status import GmailMatchStatus
from app.models.enums.notification_type import NotificationType
from app.schemas.gmail import GmailMatchConfirmRequest
from app.services.gmail.gmail_service import GmailService
from app.services.notifications.notification_service import NotificationService


class _Notes:
    """Records every push so the payload contract can be asserted directly."""

    def __init__(self) -> None:
        self.pushed: list[dict[str, Any]] = []

    def create(self, user_id: str, data: dict[str, Any]) -> dict[str, Any]:
        payload = {**data, "id": "n1", "user_id": user_id, "read": False}
        self.pushed.append(payload)
        return payload

    def list(self, user_id: str, *, limit: int = 50):
        return []

    def unread_count(self, user_id: str) -> int:
        return 0

    def mark_read(self, user_id: str, notification_id: str):
        return None

    def mark_all_read(self, user_id: str) -> int:
        return 0

    def delete(self, user_id: str, notification_id: str) -> bool:
        return False

    def get_preferences(self, user_id: str):
        return {}

    def set_preferences(self, user_id: str, prefs: dict[str, Any]):
        return prefs


class _Devices:
    def list_active(self, user_id: str):
        return []


class _StatusSpy:
    def __init__(self) -> None:
        self.calls: list[tuple[str, Any]] = []

    def change_status(self, user_id: str, application_id: str, payload) -> None:
        self.calls.append((application_id, payload.status))


class _InterviewsSpy:
    def __init__(self) -> None:
        self.calls: list[tuple[str, Any]] = []

    def create(self, user_id: str, application_id: str, payload):
        self.calls.append((application_id, payload))
        return {"id": "i1", "application_id": application_id}


class _Activities:
    def record(self, user_id: str, application_id: str, **kwargs) -> None:
        return None


@pytest.fixture(autouse=True)
def _encryption_key(monkeypatch):
    monkeypatch.setenv("ENCRYPTION_KEY", "contract-test-secret-key")
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


@pytest.fixture
def notifier():
    notes = _Notes()
    fcm = MagicMock()
    fcm.send_to_user.return_value = []
    svc = NotificationService(
        notification_repository=notes,  # type: ignore
        device_repository=_Devices(),  # type: ignore
        fcm_service=fcm,
    )
    return svc, notes


def test_gmail_push_uses_thread_id(notifier):
    """The Flutter router resolves `thread_id`; the old key silently broke it."""
    svc, notes = notifier

    svc.create_and_push(
        "u1",
        type=NotificationType.GMAIL_EMAIL_DETECTED,
        title="Interview invitation",
        body="Acme replied",
        data={"thread_id": "t1", "match_status": GmailMatchStatus.SUGGESTED.value},
    )

    assert notes.pushed, "no notification was recorded"
    data = notes.pushed[-1]["data"]
    assert data["thread_id"] == "t1"
    assert "gmail_thread_id" not in data
    assert notes.pushed[-1]["type"] == NotificationType.GMAIL_EMAIL_DETECTED.value


def test_push_always_carries_type_and_notification_id(notifier):
    svc, notes = notifier

    svc.create_and_push(
        "u1",
        type=NotificationType.INTERVIEW_REMINDER,
        title="Interview",
        body="Tomorrow",
        data={"interview_id": "i1"},
    )

    payload = notes.pushed[-1]
    assert payload["type"]
    assert payload["id"] == "n1"
    assert payload["data"]["interview_id"] == "i1"


def test_notification_without_devices_is_still_persisted(notifier):
    """Inbox entries must exist even when no device can receive the push."""
    svc, notes = notifier

    result = svc.create_and_push(
        "u1",
        type=NotificationType.SYSTEM,
        title="Heads up",
        body="Something happened",
    )

    assert result is not None
    assert notes.pushed[-1]["title"] == "Heads up"


class _ThreadsRepo:
    def __init__(self) -> None:
        self.rows: dict[str, dict[str, Any]] = {
            "t1": {
                "id": "t1",
                "user_id": "u1",
                "gmail_thread_id": "g1",
                "subject": "Interview invitation",
                "match_status": GmailMatchStatus.SUGGESTED.value,
                "suggested_application_id": "a1",
            }
        }

    def get(self, user_id: str, thread_id: str):
        row = self.rows.get(thread_id)
        return row if row and row["user_id"] == user_id else None

    def update(self, user_id: str, thread_id: str, data: dict[str, Any]):
        self.rows[thread_id].update(data)
        return self.rows[thread_id]

    def list(self, user_id: str, **kwargs):
        return [r for r in self.rows.values() if r["user_id"] == user_id]


class _MessagesRepo:
    def __init__(self) -> None:
        self.rows = [{"id": "m1", "user_id": "u1", "gmail_thread_id": "g1"}]

    def list(self, user_id: str, **kwargs):
        return [r for r in self.rows if r["user_id"] == user_id]

    def update(self, user_id: str, message_id: str, data: dict[str, Any]):
        return None

    def get(self, user_id: str, message_id: str):
        return None


class _AppsRepo:
    def get(self, user_id: str, application_id: str):
        if application_id == "a1":
            return {"id": "a1", "user_id": user_id, "company_name": "Acme"}
        return None


@pytest.fixture
def gmail():
    status = _StatusSpy()
    interviews = _InterviewsSpy()
    svc = GmailService(
        thread_repository=_ThreadsRepo(),  # type: ignore
        message_repository=_MessagesRepo(),  # type: ignore
        application_repository=_AppsRepo(),  # type: ignore
        status_service=status,  # type: ignore
        interview_service=interviews,  # type: ignore
        activity_service=_Activities(),  # type: ignore
    )
    return svc, status, interviews


def test_confirm_links_without_mutating(gmail):
    """The default confirmation must only link."""
    svc, status, interviews = gmail

    result = svc.confirm_match("u1", "t1", GmailMatchConfirmRequest(application_id="a1"))

    assert result.match_status == GmailMatchStatus.MATCHED.value
    assert result.application_id == "a1"
    assert status.calls == [], "a status change happened without consent"
    assert interviews.calls == [], "an interview was created without consent"


def test_confirm_applies_status_only_when_requested(gmail):
    svc, status, interviews = gmail

    svc.confirm_match(
        "u1",
        "t1",
        GmailMatchConfirmRequest(application_id="a1", confirm_status="SHORTLISTED"),
    )

    assert len(status.calls) == 1
    assert status.calls[0][0] == "a1"
    assert interviews.calls == []


def test_confirm_creates_interview_only_when_requested(gmail):
    svc, status, interviews = gmail
    scheduled = (datetime.now(timezone.utc) + timedelta(days=2)).isoformat()

    svc.confirm_match(
        "u1",
        "t1",
        GmailMatchConfirmRequest(
            application_id="a1",
            create_interview=True,
            interview={
                "type": "TECHNICAL_INTERVIEW",
                "title": "Technical round",
                "scheduled_at": scheduled,
                "duration_minutes": 60,
            },
        ),
    )

    assert len(interviews.calls) == 1
    application_id, payload = interviews.calls[0]
    assert application_id == "a1"
    assert payload.title == "Technical round"
    assert status.calls == [], "an interview request must not imply a status change"


def test_create_interview_without_a_schedule_is_rejected(gmail):
    from app.core.exceptions import ValidationError

    svc, status, interviews = gmail

    with pytest.raises(ValidationError):
        svc.confirm_match(
            "u1",
            "t1",
            GmailMatchConfirmRequest(
                application_id="a1",
                create_interview=True,
                interview={"type": "TECHNICAL_INTERVIEW", "title": "No time given"},
            ),
        )

    assert interviews.calls == []


def test_confirm_does_not_leak_across_users(gmail):
    from app.core.exceptions import NotFoundError

    svc, _, _ = gmail

    with pytest.raises(NotFoundError):
        svc.confirm_match("u2", "t1", GmailMatchConfirmRequest(application_id="a1"))


def test_ignore_does_not_mutate_the_application(gmail):
    svc, status, interviews = gmail

    result = svc.ignore_match("u1", "t1")

    assert result.match_status == GmailMatchStatus.IGNORED.value
    assert status.calls == []
    assert interviews.calls == []
