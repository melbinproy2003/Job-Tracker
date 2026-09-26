"""Phase 4 notifications + Phase 5 Gmail unit tests (in-memory)."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any
from unittest.mock import MagicMock

import pytest

from app.models.enums.device_platform import DevicePlatform
from app.models.enums.gmail_match_status import GmailMatchStatus
from app.models.enums.interview_status import InterviewStatus
from app.models.enums.interview_type import InterviewType
from app.models.enums.notification_type import NotificationType
from app.schemas.notification import DeviceRegisterRequest, NotificationPreferences
from app.services.gmail.application_matcher import ApplicationMatcher
from app.services.gmail.job_email_detector import JobEmailDetector
from app.services.notifications.notification_service import NotificationService
from app.services.notifications.reminder_service import ReminderService
from app.utils.email import normalize_email, normalize_subject
from app.utils.encryption import decrypt_secret, encrypt_secret
from app.core.config import get_settings


class InMemoryNotificationRepo:
    def __init__(self) -> None:
        self._data: dict[str, dict[str, dict[str, Any]]] = {}
        self._prefs: dict[str, dict[str, Any]] = {}

    def create(self, user_id: str, data: dict[str, Any]) -> dict[str, Any]:
        self._data.setdefault(user_id, {})
        dedupe = data.pop("dedupe_key", None)
        nid = dedupe or f"n{len(self._data[user_id]) + 1}"
        if dedupe and nid in self._data[user_id]:
            out = dict(self._data[user_id][nid])
            out["_duplicate"] = True
            return out
        now = datetime.now(timezone.utc)
        payload = {
            **data,
            "id": nid,
            "user_id": user_id,
            "read": False,
            "sent_at": now,
            "created_at": now,
        }
        if dedupe:
            payload["dedupe_key"] = dedupe
        self._data[user_id][nid] = payload
        return payload

    def list(self, user_id: str, *, limit: int = 50):
        items = list(self._data.get(user_id, {}).values())
        items.sort(key=lambda x: x["created_at"], reverse=True)
        return items[:limit]

    def unread_count(self, user_id: str) -> int:
        return sum(1 for n in self.list(user_id, limit=500) if not n.get("read"))

    def mark_read(self, user_id: str, notification_id: str):
        n = self._data.get(user_id, {}).get(notification_id)
        if not n:
            return None
        n["read"] = True
        return n

    def mark_all_read(self, user_id: str) -> int:
        count = 0
        for n in self._data.get(user_id, {}).values():
            if not n.get("read"):
                n["read"] = True
                count += 1
        return count

    def delete(self, user_id: str, notification_id: str) -> bool:
        return self._data.get(user_id, {}).pop(notification_id, None) is not None

    def get_preferences(self, user_id: str):
        from app.repositories.notification_repository import DEFAULT_PREFS

        return {**DEFAULT_PREFS, **self._prefs.get(user_id, {})}

    def set_preferences(self, user_id: str, prefs: dict[str, Any]):
        from app.repositories.notification_repository import DEFAULT_PREFS

        self._prefs[user_id] = {**DEFAULT_PREFS, **prefs}
        return self._prefs[user_id]


class InMemoryDeviceRepo:
    def __init__(self) -> None:
        self._data: dict[str, dict[str, dict[str, Any]]] = {}

    def find_by_token(self, user_id: str, fcm_token: str):
        for d in self._data.get(user_id, {}).values():
            if d.get("fcm_token") == fcm_token:
                return d
        return None

    def create(self, user_id: str, data: dict[str, Any]):
        self._data.setdefault(user_id, {})
        did = f"d{len(self._data[user_id]) + 1}"
        payload = {**data, "id": did, "user_id": user_id, "is_active": True}
        self._data[user_id][did] = payload
        return payload

    def update(self, user_id: str, device_id: str, data: dict[str, Any]):
        current = self._data[user_id][device_id]
        current.update(data)
        return current

    def list_active(self, user_id: str):
        return [d for d in self._data.get(user_id, {}).values() if d.get("is_active", True)]

    def get(self, user_id: str, device_id: str):
        return self._data.get(user_id, {}).get(device_id)

    def delete(self, user_id: str, device_id: str):
        self._data.get(user_id, {}).pop(device_id, None)

    def deactivate(self, user_id: str, device_id: str):
        self.update(user_id, device_id, {"is_active": False})


@pytest.fixture(autouse=True)
def _encryption_key(monkeypatch):
    monkeypatch.setenv("ENCRYPTION_KEY", "phase45-test-secret-key")
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


@pytest.fixture
def notification_svc():
    notes = InMemoryNotificationRepo()
    devices = InMemoryDeviceRepo()
    fcm = MagicMock()
    fcm.send_to_user.return_value = []
    from app.services.notifications.fcm_service import FcmService

    svc = NotificationService(
        notification_repository=notes,
        device_repository=devices,
        fcm_service=fcm,
    )
    return svc, notes, devices, fcm


def test_device_registration_and_refresh(notification_svc):
    svc, _, devices, _ = notification_svc
    created = svc.register_device(
        "u1",
        DeviceRegisterRequest(
            fcm_token="token-abc-123456",
            platform=DevicePlatform.ANDROID,
            device_name="Pixel",
            app_version="1.0.0",
        ),
    )
    assert created.registered is True
    refreshed = svc.register_device(
        "u1",
        DeviceRegisterRequest(
            fcm_token="token-abc-123456",
            platform=DevicePlatform.ANDROID,
            device_name="Pixel 2",
        ),
    )
    assert refreshed.id == created.id
    assert len(devices.list_active("u1")) == 1


def test_notifications_mark_read_and_dedupe(notification_svc):
    svc, notes, _, fcm = notification_svc
    first = svc.create_and_push(
        "u1",
        type=NotificationType.INTERVIEW_REMINDER,
        title="Interview",
        body="Soon",
        dedupe_key="interview_i1_24h",
    )
    assert first is not None
    second = svc.create_and_push(
        "u1",
        type=NotificationType.INTERVIEW_REMINDER,
        title="Interview",
        body="Soon",
        dedupe_key="interview_i1_24h",
    )
    assert second is None
    assert len(svc.list("u1")) == 1
    assert svc.unread_count("u1").count == 1
    svc.mark_read("u1", first.id)
    assert svc.unread_count("u1").count == 0
    assert fcm.send_to_user.call_count == 1


def test_notification_preferences(notification_svc):
    svc, _, _, _ = notification_svc
    prefs = svc.update_preferences(
        "u1",
        NotificationPreferences(gmail_notifications=False, interview_reminders=True),
    )
    assert prefs.gmail_notifications is False
    loaded = svc.get_preferences("u1")
    assert loaded.gmail_notifications is False


def test_user_isolation_notifications(notification_svc):
    svc, _, _, _ = notification_svc
    svc.create_and_push(
        "u1",
        type=NotificationType.SYSTEM,
        title="Private",
        body="x",
        dedupe_key="sys1",
    )
    assert svc.list("u2") == []


def test_encryption_roundtrip():
    token = "gmail-refresh-token-secret"
    enc = encrypt_secret(token)
    assert enc != token
    assert decrypt_secret(enc) == token


def test_email_normalization():
    assert normalize_email("HR@Company.COM") == "hr@company.com"
    assert normalize_email("Name <Careers@ABC.com>") == "careers@abc.com"
    assert normalize_subject("Re: Fwd: Interview Invitation") == "Interview Invitation"


def test_job_email_detector_and_matcher():
    detector = JobEmailDetector()
    msg = {
        "subject": "Interview Invitation - Junior Python Developer",
        "snippet": "We would like to schedule a technical interview",
        "body_text": "Please join https://meet.example.com/abc on Sep 29 at 10:00 AM",
        "from_address": "careers@abc.com",
    }
    detection = detector.detect(msg)
    assert detection["is_job_related"] is True
    assert detection["category"] == "INTERVIEW"

    apps = [
        {
            "id": "a1",
            "company_name": "ABC Technologies",
            "job_title": "Junior Python Developer",
            "recruiter_email": None,
        },
        {
            "id": "a2",
            "company_name": "XYZ Software",
            "job_title": "React Developer",
        },
    ]
    candidates = ApplicationMatcher().find_candidates(message=msg, applications=apps)
    assert candidates
    assert candidates[0]["application_id"] == "a1"
    assert candidates[0]["confidence"] >= 40


def test_reminder_interview_dedupe():
    notes = InMemoryNotificationRepo()
    devices = InMemoryDeviceRepo()
    fcm = MagicMock()
    fcm.send_to_user.return_value = []
    notifier = NotificationService(
        notification_repository=notes,
        device_repository=devices,
        fcm_service=fcm,
    )

    class AppRepo:
        def list_all(self, user_id):
            return [{"id": "a1", "company_name": "ABC"}]

    class InterviewRepo:
        def list_all_for_user(self, user_id, application_ids):
            scheduled = datetime.now(timezone.utc) + timedelta(hours=24)
            # Align so target window includes now for 24h reminder
            return [
                {
                    "id": "i1",
                    "application_id": "a1",
                    "status": InterviewStatus.SCHEDULED.value,
                    "scheduled_at": scheduled,
                    "title": "Technical Interview",
                    "company_name": "ABC",
                    "type": InterviewType.TECHNICAL_INTERVIEW.value,
                }
            ]

    class FollowRepo:
        def list_all(self, user_id):
            return []

    reminder = ReminderService(
        application_repository=AppRepo(),  # type: ignore
        interview_repository=InterviewRepo(),  # type: ignore
        followup_repository=FollowRepo(),  # type: ignore
        notification_service=notifier,
        notification_repository=notes,
    )
    # Force now exactly at 24h-before window start
    scheduled = datetime.now(timezone.utc) + timedelta(hours=24)
    now = scheduled - timedelta(hours=24) + timedelta(minutes=1)
    # Patch interview scheduled_at relative to now
    InterviewRepo.list_all_for_user = lambda self, user_id, application_ids: [
        {
            "id": "i1",
            "application_id": "a1",
            "status": InterviewStatus.SCHEDULED.value,
            "scheduled_at": now + timedelta(hours=24),
            "title": "Technical Interview",
            "company_name": "ABC",
        }
    ]
    r1 = reminder.process_user("u1", now=now)
    r2 = reminder.process_user("u1", now=now)
    assert r1["interview"] == 1
    assert r2["interview"] == 0
