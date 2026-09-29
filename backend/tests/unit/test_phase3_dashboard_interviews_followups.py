"""Phase 3 dashboard, interviews, follow-ups, and activities tests."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest
from fastapi.testclient import TestClient

from app.api.v1 import applications as applications_api
from app.api.v1 import dashboard as dashboard_api
from app.api.v1 import followups as followups_api
from app.api.v1 import interviews as interviews_api
from app.core.exceptions import (
    FollowUpDuplicateError,
    InterviewConflictError,
    InterviewNotFoundError,
)
from app.main import create_app
from app.models.enums.activity_type import ActivityType
from app.models.enums.application_status import ApplicationStatus
from app.models.enums.interview_status import InterviewStatus
from app.models.enums.interview_type import InterviewType
from app.schemas.application import ApplicationCreateRequest, ApplicationStatusUpdateRequest
from app.schemas.company import CompanyCreateRequest
from app.schemas.followup import FollowUpCreateRequest
from app.schemas.interview import InterviewCreateRequest, InterviewUpdateRequest
from app.services.dashboard.dashboard_service import DashboardService
from app.services.followups.followup_service import FollowUpService
from app.services.interviews.interview_service import InterviewService
from tests.unit.test_phase2_applications import stores as stores_fixture  # noqa: F401


@pytest.fixture
def phase3(stores_fixture):
    stores = stores_fixture
    interview_svc = InterviewService(
        interview_repository=stores["interviews"],
        application_repository=stores["apps"],
        activity_service=stores["activity_svc"],
    )
    followup_svc = FollowUpService(
        followup_repository=stores["followups"],
        application_repository=stores["apps"],
        activity_service=stores["activity_svc"],
    )
    dashboard_svc = DashboardService(
        application_repository=stores["apps"],
        interview_repository=stores["interviews"],
        followup_repository=stores["followups"],
    )
    stores["interview_svc"] = interview_svc
    stores["followup_svc"] = followup_svc
    stores["dashboard_svc"] = dashboard_svc
    return stores


def _seed_app(phase3, user_id="u1", status=ApplicationStatus.APPLIED, title="Python Dev"):
    company = phase3["company_svc"].create(user_id, CompanyCreateRequest(name="ABC Technologies"))
    app = phase3["app_svc"].create(
        user_id,
        ApplicationCreateRequest(company_id=company.id, job_title=title, status=status),
    )
    return company, app


def test_interview_crud_and_ownership(phase3):
    _, app = _seed_app(phase3)
    svc: InterviewService = phase3["interview_svc"]
    scheduled = datetime.now(timezone.utc) + timedelta(days=2)
    created = svc.create(
        "u1",
        app.id,
        InterviewCreateRequest(
            type=InterviewType.TECHNICAL_INTERVIEW,
            scheduled_at=scheduled,
            duration_minutes=60,
            meeting_url="https://meet.example.com/abc",
            interviewer_name="John Doe",
            interviewer_email="john@example.com",
        ),
    )
    assert created.type == InterviewType.TECHNICAL_INTERVIEW
    assert created.status == InterviewStatus.SCHEDULED
    assert created.company_name == "ABC Technologies"

    listed = svc.list_for_application("u1", app.id)
    assert len(listed) == 1

    got = svc.get("u1", created.id)
    assert got.id == created.id

    with pytest.raises(InterviewNotFoundError):
        svc.get("u2", created.id)

    updated = svc.update(
        "u1",
        created.id,
        InterviewUpdateRequest(status=InterviewStatus.COMPLETED, force=True),
    )
    assert updated.status == InterviewStatus.COMPLETED

    activities = phase3["activity_svc"].list_for_application("u1", app.id)
    types = {a.type for a in activities}
    assert ActivityType.INTERVIEW_CREATED in types
    assert ActivityType.INTERVIEW_COMPLETED in types

    svc.delete("u1", created.id)
    with pytest.raises(InterviewNotFoundError):
        svc.get("u1", created.id)


def test_interview_conflict_warning(phase3):
    _, app = _seed_app(phase3)
    svc: InterviewService = phase3["interview_svc"]
    start = datetime.now(timezone.utc) + timedelta(days=1)
    svc.create(
        "u1",
        app.id,
        InterviewCreateRequest(
            type=InterviewType.HR_INTERVIEW,
            scheduled_at=start,
            duration_minutes=60,
        ),
    )
    with pytest.raises(InterviewConflictError):
        svc.create(
            "u1",
            app.id,
            InterviewCreateRequest(
                type=InterviewType.TECHNICAL_INTERVIEW,
                scheduled_at=start + timedelta(minutes=30),
                duration_minutes=60,
            ),
        )
    # force override
    forced = svc.create(
        "u1",
        app.id,
        InterviewCreateRequest(
            type=InterviewType.TECHNICAL_INTERVIEW,
            scheduled_at=start + timedelta(minutes=30),
            duration_minutes=60,
            force=True,
        ),
    )
    assert forced.id


def test_followup_complete_undo_overdue_duplicate(phase3):
    _, app = _seed_app(phase3)
    svc: FollowUpService = phase3["followup_svc"]
    past = datetime.now(timezone.utc) - timedelta(days=2)
    future = datetime.now(timezone.utc) + timedelta(days=1)

    overdue = svc.create(
        "u1",
        FollowUpCreateRequest(
            application_id=app.id,
            title="Follow up with recruiter",
            scheduled_at=past,
        ),
    )
    assert overdue.is_overdue is True

    pending = svc.create(
        "u1",
        FollowUpCreateRequest(
            application_id=app.id,
            title="Send thank-you message",
            scheduled_at=future,
        ),
    )
    assert pending.is_overdue is False

    with pytest.raises(FollowUpDuplicateError):
        svc.create(
            "u1",
            FollowUpCreateRequest(
                application_id=app.id,
                title="Follow up with recruiter",
                scheduled_at=past,
            ),
        )

    completed = svc.complete("u1", overdue.id)
    assert completed.completed is True
    assert completed.completed_at is not None
    assert completed.is_overdue is False

    reopened = svc.reopen("u1", overdue.id)
    assert reopened.completed is False
    assert reopened.completed_at is None

    activities = phase3["activity_svc"].list_for_application("u1", app.id)
    types = {a.type for a in activities}
    assert ActivityType.FOLLOWUP_CREATED in types
    assert ActivityType.FOLLOWUP_COMPLETED in types


def test_dashboard_totals_isolation_and_distribution(phase3):
    company, app = _seed_app(phase3, status=ApplicationStatus.APPLIED)
    phase3["app_svc"].create(
        "u1",
        ApplicationCreateRequest(
            company_id=company.id,
            job_title="Offer Role",
            status=ApplicationStatus.OFFER,
        ),
    )
    phase3["app_svc"].create(
        "u1",
        ApplicationCreateRequest(
            company_id=company.id,
            job_title="Rejected Role",
            status=ApplicationStatus.REJECTED,
        ),
    )
    phase3["status_svc"].change_status(
        "u1",
        app.id,
        ApplicationStatusUpdateRequest(status=ApplicationStatus.TECHNICAL_ROUND),
    )

    future = datetime.now(timezone.utc) + timedelta(days=3)
    past = datetime.now(timezone.utc) - timedelta(days=1)
    phase3["interview_svc"].create(
        "u1",
        app.id,
        InterviewCreateRequest(
            type=InterviewType.FINAL_INTERVIEW,
            scheduled_at=future,
            duration_minutes=45,
        ),
    )
    phase3["followup_svc"].create(
        "u1",
        FollowUpCreateRequest(
            application_id=app.id,
            title="Check status",
            scheduled_at=past,
        ),
    )
    phase3["followup_svc"].create(
        "u1",
        FollowUpCreateRequest(
            application_id=app.id,
            title="Upcoming note",
            scheduled_at=future,
        ),
    )

    # other user data must not leak
    other_company = phase3["company_svc"].create("u2", CompanyCreateRequest(name="Other"))
    phase3["app_svc"].create(
        "u2",
        ApplicationCreateRequest(company_id=other_company.id, job_title="Secret"),
    )

    dash = phase3["dashboard_svc"].get_dashboard("u1")
    assert dash.total_applications == 3
    assert dash.offers == 1
    assert dash.rejected == 1
    assert dash.upcoming_interviews == 1
    assert dash.overdue_followups == 1
    assert dash.pending_followups == 2
    assert dash.status_distribution.get("TECHNICAL_ROUND") == 1
    assert dash.status_distribution.get("OFFER") == 1
    assert any(e.kind == "interview" for e in dash.upcoming_events)
    assert any(e.kind == "followup" for e in dash.upcoming_events)

    other_dash = phase3["dashboard_svc"].get_dashboard("u2")
    assert other_dash.total_applications == 1
    assert other_dash.offers == 0


def test_application_create_and_status_activities(phase3):
    _, app = _seed_app(phase3)
    phase3["status_svc"].change_status(
        "u1",
        app.id,
        ApplicationStatusUpdateRequest(status=ApplicationStatus.HR_CALL),
    )
    activities = phase3["activity_svc"].list_for_application("u1", app.id)
    types = [a.type for a in activities]
    assert ActivityType.APPLICATION_CREATED in types
    assert ActivityType.STATUS_CHANGED in types


def test_api_phase3_endpoints(phase3):
    app = create_app()
    client = TestClient(app)
    import app.api.v1.dependencies as deps

    original = deps.verify_firebase_id_token

    async def _ok(_token: str):
        return {"uid": "u1", "email": "a@b.com", "name": "A", "email_verified": True}

    deps.verify_firebase_id_token = _ok  # type: ignore
    app.dependency_overrides[applications_api.get_application_service] = lambda: phase3["app_svc"]
    app.dependency_overrides[applications_api.get_status_service] = lambda: phase3["status_svc"]
    app.dependency_overrides[applications_api.get_interview_service] = lambda: phase3[
        "interview_svc"
    ]
    app.dependency_overrides[applications_api.get_activity_service] = lambda: phase3["activity_svc"]
    app.dependency_overrides[interviews_api.get_interview_service] = lambda: phase3["interview_svc"]
    app.dependency_overrides[followups_api.get_followup_service] = lambda: phase3["followup_svc"]
    app.dependency_overrides[dashboard_api.get_dashboard_service] = lambda: phase3["dashboard_svc"]

    try:
        company = phase3["company_svc"].create("u1", CompanyCreateRequest(name="API Co"))
        created_app = phase3["app_svc"].create(
            "u1",
            ApplicationCreateRequest(company_id=company.id, job_title="API Role"),
        )
        scheduled = (
            (datetime.now(timezone.utc) + timedelta(days=2)).isoformat().replace("+00:00", "Z")
        )
        iv = client.post(
            f"/api/v1/applications/{created_app.id}/interviews",
            headers={"Authorization": "Bearer token"},
            json={
                "type": "TECHNICAL_INTERVIEW",
                "scheduled_at": scheduled,
                "duration_minutes": 60,
                "meeting_url": "https://meet.example.com/x",
            },
        )
        assert iv.status_code == 201, iv.text

        fu = client.post(
            "/api/v1/followups",
            headers={"Authorization": "Bearer token"},
            json={
                "application_id": created_app.id,
                "title": "Follow up with recruiter",
                "scheduled_at": scheduled,
            },
        )
        assert fu.status_code == 201, fu.text
        fu_id = fu.json()["id"]

        complete = client.patch(
            f"/api/v1/followups/{fu_id}/complete",
            headers={"Authorization": "Bearer token"},
        )
        assert complete.status_code == 200
        assert complete.json()["completed"] is True

        dash = client.get("/api/v1/dashboard", headers={"Authorization": "Bearer token"})
        assert dash.status_code == 200
        body = dash.json()
        assert body["total_applications"] >= 1
        assert "status_distribution" in body

        acts = client.get(
            f"/api/v1/applications/{created_app.id}/activities",
            headers={"Authorization": "Bearer token"},
        )
        assert acts.status_code == 200
        assert len(acts.json()) >= 2
    finally:
        deps.verify_firebase_id_token = original
        app.dependency_overrides.clear()
