"""Phase 6 email intelligence + Python↔Flutter interview contract tests."""

from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from typing import Any

import pytest

from app.core.exceptions import InterviewConflictError
from app.models.enums.gmail_match_status import GmailMatchStatus
from app.schemas.gmail import GmailMatchConfirmRequest, InterviewSuggestion
from app.services.gmail.application_matcher import ApplicationMatcher
from app.services.gmail.gmail_retention_service import GmailRetentionService
from app.services.gmail.gmail_service import GmailService
from app.services.gmail.job_email_detector import JobEmailDetector

# Keys the Flutter InterviewSuggestion.fromJson must accept.
FLUTTER_INTERVIEW_KEYS = {
    "title",
    "scheduled_at",
    "duration_minutes",
    "meeting_url",
    "location",
    "interviewer_name",
    "interviewer_email",
    "interview_type",
    "type",
    "confidence",
}
FORBIDDEN_HINT_KEYS = {"date_hint", "time_hint"}


class _ThreadRepo:
    def __init__(self) -> None:
        self._data: dict[str, dict[str, Any]] = {
            "t1": {
                "id": "t1",
                "gmail_thread_id": "gt1",
                "subject": "Interview Invitation",
                "match_status": GmailMatchStatus.SUGGESTED.value,
                "suggested_status": "TECHNICAL_ROUND",
                "applied_actions": [],
            }
        }

    def get(self, user_id: str, thread_id: str):
        if user_id != "u1":
            return None
        return self._data.get(thread_id)

    def update(self, user_id: str, thread_id: str, data: dict[str, Any]):
        cur = self._data[thread_id]
        cur.update(data)
        return cur

    def list(self, user_id: str, *, application_id: str | None = None):
        items = list(self._data.values())
        if application_id:
            items = [
                t
                for t in items
                if t.get("application_id") == application_id
                or t.get("suggested_application_id") == application_id
            ]
        return items


class _MsgRepo:
    def list(self, user_id: str, *, thread_id: str | None = None):
        return []

    def update(self, user_id: str, message_id: str, data: dict[str, Any]):
        return {"id": message_id, **data}


class _AppRepo:
    def get(self, user_id: str, application_id: str):
        if user_id == "u1" and application_id == "a1":
            return {"id": "a1", "company_name": "ABC", "job_title": "Dev"}
        return None

    def list_all(self, user_id: str):
        return [
            {"id": "a1", "company_name": "ABC Technologies", "job_title": "Junior Python Developer"}
        ]


class _StatusSpy:
    def __init__(self) -> None:
        self.calls: list[Any] = []

    def change_status(self, user_id, application_id, payload):
        self.calls.append((application_id, payload.status))


class _InterviewSpy:
    def __init__(self, *, conflict: bool = False) -> None:
        self.calls: list[Any] = []
        self.conflict = conflict

    def create(self, user_id, application_id, payload):
        self.calls.append((application_id, payload))
        if self.conflict and not payload.force:
            raise InterviewConflictError()
        return type("IV", (), {"id": "i1"})()


class _Activities:
    def __init__(self) -> None:
        self.calls: list[Any] = []

    def record(self, user_id, application_id, **kwargs):
        self.calls.append((application_id, kwargs.get("type")))


@pytest.fixture
def gmail_svc():
    threads = _ThreadRepo()
    status = _StatusSpy()
    interviews = _InterviewSpy()
    activities = _Activities()
    svc = GmailService(
        thread_repository=threads,
        message_repository=_MsgRepo(),
        application_repository=_AppRepo(),
        status_service=status,
        interview_service=interviews,
        activity_service=activities,
    )
    return svc, threads, status, interviews, activities


def test_classification_categories_and_signals():
    detector = JobEmailDetector()
    offer = detector.detect(
        {
            "subject": "Your offer letter",
            "snippet": "We are pleased to offer you the role",
            "body_text": "",
            "from_address": "hr@acme.com",
        }
    )
    assert offer["category"] == "OFFER"
    assert offer["suggested_status"] == "OFFER"
    assert offer["confidence"] > 0.5

    rejection = detector.detect(
        {
            "subject": "Application update",
            "snippet": "Unfortunately we have decided to move forward with other candidates",
            "body_text": "",
            "from_address": "careers@x.com",
        }
    )
    assert rejection["category"] == "REJECTION"
    assert rejection["suggested_status"] == "REJECTED"


def test_interview_extraction_contract_has_scheduled_at_not_hints():
    detector = JobEmailDetector()
    detection = detector.detect(
        {
            "subject": "Technical interview - Backend",
            "snippet": "Interview scheduled Sep 29, 2026 at 10:00 AM",
            "body_text": "Join https://meet.example.com/x on Sep 29, 2026 at 10:00 AM",
            "from_address": "careers@abc.com",
        }
    )
    suggestion = detection["interview_suggestion"]
    assert suggestion is not None
    for key in FORBIDDEN_HINT_KEYS:
        assert key not in suggestion
    assert suggestion["scheduled_at"] is not None
    assert suggestion["interview_type"] == "TECHNICAL_INTERVIEW"
    assert suggestion["type"] == suggestion["interview_type"]
    assert set(suggestion.keys()) <= FLUTTER_INTERVIEW_KEYS or FLUTTER_INTERVIEW_KEYS.issubset(
        set(suggestion.keys())
    )

    # Must serialize through the Pydantic contract used by the API.
    model = InterviewSuggestion.model_validate(suggestion)
    payload = json.loads(model.model_dump_json(exclude_none=False))
    assert "scheduled_at" in payload
    assert "date_hint" not in payload
    assert "time_hint" not in payload


def test_matcher_ranks_and_explains():
    matcher = ApplicationMatcher()
    msg = {
        "subject": "Interview Invitation - Junior Python Developer",
        "body_text": "Hello from ABC Technologies in Bangalore",
        "from_address": "careers@abc.com",
        "received_at": datetime.now(timezone.utc),
    }
    apps = [
        {
            "id": "a1",
            "company_name": "ABC Technologies",
            "job_title": "Junior Python Developer",
            "location": "Bangalore",
            "applied_at": datetime.now(timezone.utc) - timedelta(days=5),
        },
        {
            "id": "a2",
            "company_name": "XYZ Software",
            "job_title": "React Developer",
        },
    ]
    candidates = matcher.find_candidates(message=msg, applications=apps)
    assert candidates[0]["application_id"] == "a1"
    assert candidates[0]["confidence"] >= candidates[-1]["confidence"]
    assert candidates[0]["reasons"]
    assert any("domain" in r.lower() or "company" in r.lower() for r in candidates[0]["reasons"])
    assert candidates[0]["confidence_band"] in {"VERY_HIGH", "HIGH", "MEDIUM", "LOW"}


def test_application_draft_from_unmatched_email():
    draft = ApplicationMatcher().build_application_draft(
        {
            "subject": "Application received - Backend Engineer",
            "from_address": "jobs@examplecorp.com",
            "body_text": "Apply at https://examplecorp.com/jobs/1",
            "received_at": datetime.now(timezone.utc),
        }
    )
    assert draft["source"] == "Gmail"
    assert draft["recruiter_email"] == "jobs@examplecorp.com"
    assert draft["company_domain"] == "examplecorp.com"
    assert draft["job_url"]


def test_confirm_idempotent_link_and_status(gmail_svc):
    svc, threads, status, interviews, activities = gmail_svc
    first = svc.confirm_match(
        "u1",
        "t1",
        GmailMatchConfirmRequest(application_id="a1", confirm_status="TECHNICAL_ROUND"),
    )
    assert first.applied is True
    assert len(status.calls) == 1

    second = svc.confirm_match(
        "u1",
        "t1",
        GmailMatchConfirmRequest(application_id="a1", confirm_status="TECHNICAL_ROUND"),
    )
    assert second.applied is False
    assert len(status.calls) == 1  # no duplicate status change
    assert "link:a1" in threads._data["t1"]["applied_actions"]


def test_confirm_interview_idempotent_and_no_force_by_default(gmail_svc):
    svc, threads, status, interviews, _ = gmail_svc
    scheduled = (datetime.now(timezone.utc) + timedelta(days=2)).isoformat()
    payload = GmailMatchConfirmRequest(
        application_id="a1",
        create_interview=True,
        interview={
            "interview_type": "TECHNICAL_INTERVIEW",
            "type": "TECHNICAL_INTERVIEW",
            "title": "Tech",
            "scheduled_at": scheduled,
            "duration_minutes": 60,
        },
    )
    first = svc.confirm_match("u1", "t1", payload)
    assert first.interview_created is True
    assert len(interviews.calls) == 1
    assert interviews.calls[0][1].force is False

    second = svc.confirm_match("u1", "t1", payload)
    assert second.interview_created is False
    assert len(interviews.calls) == 1


def test_confirm_surfaces_interview_conflict_without_force():
    threads = _ThreadRepo()
    interviews = _InterviewSpy(conflict=True)
    svc = GmailService(
        thread_repository=threads,
        message_repository=_MsgRepo(),
        application_repository=_AppRepo(),
        status_service=_StatusSpy(),
        interview_service=interviews,
        activity_service=_Activities(),
    )
    scheduled = (datetime.now(timezone.utc) + timedelta(days=2)).isoformat()
    result = svc.confirm_match(
        "u1",
        "t1",
        GmailMatchConfirmRequest(
            application_id="a1",
            create_interview=True,
            interview={
                "type": "TECHNICAL_INTERVIEW",
                "title": "Tech",
                "scheduled_at": scheduled,
            },
        ),
    )
    assert result.interview_conflict is True
    assert result.interview_created is False
    assert result.conflict_message


def test_unlink_match(gmail_svc):
    svc, threads, *_ = gmail_svc
    svc.confirm_match("u1", "t1", GmailMatchConfirmRequest(application_id="a1"))
    result = svc.unlink_match("u1", "t1")
    assert result.match_status == GmailMatchStatus.UNMATCHED
    assert threads._data["t1"].get("application_id") is None


def test_retention_clears_old_bodies_only():
    class _Msgs:
        def __init__(self):
            now = datetime.now(timezone.utc)
            self.items = [
                {
                    "id": "m1",
                    "received_at": now - timedelta(days=120),
                    "body_text": "old body",
                },
                {
                    "id": "m2",
                    "received_at": now - timedelta(days=2),
                    "body_text": "new body",
                },
            ]

        def list(self, user_id: str, **kwargs):
            return list(self.items)

        def update(self, user_id, message_id, data):
            for m in self.items:
                if m["id"] == message_id:
                    m.update(data)
                    return m
            return data

    msgs = _Msgs()
    result = GmailRetentionService(message_repository=msgs).clear_old_bodies("u1", retain_days=90)
    assert result["messages_cleared"] == 1
    assert msgs.items[0]["body_text"] is None
    assert msgs.items[1]["body_text"] == "new body"


def test_application_timeline(gmail_svc):
    svc, threads, *_ = gmail_svc
    threads._data["t1"]["application_id"] = "a1"
    threads._data["t1"]["detected_category"] = "TECHNICAL_INTERVIEW"
    threads._data["t1"]["last_message_at"] = datetime.now(timezone.utc)
    events = svc.application_timeline("u1", "a1")
    assert events
    assert events[0].thread_id == "t1"
