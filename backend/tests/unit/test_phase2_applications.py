"""Phase 2 application & company service/API tests (mocked Firestore)."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.api.v1 import applications as applications_api
from app.api.v1 import companies as companies_api
from app.core.exceptions import (
    ApplicationNotFoundError,
    CompanyHasApplicationsError,
    DuplicateCompanyError,
)
from app.main import create_app
from app.models.enums.application_status import ApplicationStatus
from app.schemas.application import (
    ApplicationCreateRequest,
    ApplicationStatusUpdateRequest,
)
from app.schemas.company import CompanyCreateRequest
from app.services.applications.application_service import ApplicationService
from app.services.applications.application_status_service import ApplicationStatusService
from app.services.companies.company_service import CompanyService


class InMemoryCompanyRepo:
    def __init__(self) -> None:
        self._data: dict[str, dict[str, dict[str, Any]]] = {}

    def create(self, user_id: str, data: dict[str, Any]) -> dict[str, Any]:
        self._data.setdefault(user_id, {})
        cid = f"c{len(self._data[user_id]) + 1}"
        payload = {
            **data,
            "id": cid,
            "user_id": user_id,
            "created_at": datetime.now(timezone.utc),
            "updated_at": datetime.now(timezone.utc),
        }
        self._data[user_id][cid] = payload
        return payload

    def get(self, user_id: str, company_id: str) -> dict[str, Any] | None:
        return self._data.get(user_id, {}).get(company_id)

    def list(self, user_id: str) -> list[dict[str, Any]]:
        return list(self._data.get(user_id, {}).values())

    def find_by_normalized_name(self, user_id: str, name: str) -> dict[str, Any] | None:
        from app.utils.text import normalize_company_name

        target = normalize_company_name(name)
        for c in self.list(user_id):
            if normalize_company_name(c.get("name", "")) == target:
                return c
        return None

    def update(self, user_id: str, company_id: str, data: dict[str, Any]) -> dict[str, Any]:
        current = self.get(user_id, company_id) or {}
        current.update(data)
        self._data[user_id][company_id] = current
        return current

    def delete(self, user_id: str, company_id: str) -> None:
        self._data.get(user_id, {}).pop(company_id, None)


class InMemoryAppRepo:
    def __init__(self) -> None:
        self._data: dict[str, dict[str, dict[str, Any]]] = {}

    def create(self, user_id: str, data: dict[str, Any]) -> dict[str, Any]:
        self._data.setdefault(user_id, {})
        aid = f"a{len(self._data[user_id]) + 1}"
        now = datetime.now(timezone.utc)
        payload = {
            **data,
            "id": aid,
            "user_id": user_id,
            "created_at": now,
            "updated_at": now,
            "last_updated_at": now,
        }
        self._data[user_id][aid] = payload
        return payload

    def get(self, user_id: str, application_id: str) -> dict[str, Any] | None:
        return self._data.get(user_id, {}).get(application_id)

    def list_all(self, user_id: str) -> list[dict[str, Any]]:
        return list(self._data.get(user_id, {}).values())

    def list_by_company(self, user_id: str, company_id: str) -> list[dict[str, Any]]:
        return [a for a in self.list_all(user_id) if a.get("company_id") == company_id]

    def count_by_company(self, user_id: str, company_id: str) -> int:
        return len(self.list_by_company(user_id, company_id))

    def update(self, user_id: str, application_id: str, data: dict[str, Any]) -> dict[str, Any]:
        current = self.get(user_id, application_id) or {}
        now = datetime.now(timezone.utc)
        current.update(data)
        current["updated_at"] = now
        current["last_updated_at"] = now
        self._data[user_id][application_id] = current
        return current

    def delete(self, user_id: str, application_id: str) -> None:
        self._data.get(user_id, {}).pop(application_id, None)


class InMemoryHistoryRepo:
    def __init__(self) -> None:
        self._data: dict[str, list[dict[str, Any]]] = {}

    def _key(self, user_id: str, application_id: str) -> str:
        return f"{user_id}:{application_id}"

    def append(self, user_id: str, application_id: str, *, previous_status, new_status, note=None):
        key = self._key(user_id, application_id)
        self._data.setdefault(key, [])
        row = {
            "id": f"h{len(self._data[key]) + 1}",
            "application_id": application_id,
            "user_id": user_id,
            "previous_status": previous_status,
            "new_status": new_status,
            "note": note,
            "changed_at": datetime.now(timezone.utc),
        }
        self._data[key].append(row)
        return row

    def list(self, user_id: str, application_id: str):
        rows = list(self._data.get(self._key(user_id, application_id), []))
        rows.reverse()
        return rows

    def delete_all(self, user_id: str, application_id: str) -> None:
        self._data.pop(self._key(user_id, application_id), None)


class InMemoryActivityRepo:
    def __init__(self) -> None:
        self._data: dict[str, list[dict[str, Any]]] = {}

    def _key(self, user_id: str, application_id: str) -> str:
        return f"{user_id}:{application_id}"

    def create(self, user_id: str, application_id: str, data: dict[str, Any]) -> dict[str, Any]:
        key = self._key(user_id, application_id)
        self._data.setdefault(key, [])
        row = {
            **data,
            "id": f"act{len(self._data[key]) + 1}",
            "user_id": user_id,
            "application_id": application_id,
            "created_at": data.get("created_at") or datetime.now(timezone.utc),
        }
        self._data[key].append(row)
        return row

    def list(self, user_id: str, application_id: str):
        rows = list(self._data.get(self._key(user_id, application_id), []))
        rows.reverse()
        return rows

    def delete_all_for_application(self, user_id: str, application_id: str) -> None:
        self._data.pop(self._key(user_id, application_id), None)


class InMemoryInterviewRepo:
    def __init__(self) -> None:
        self._data: dict[str, dict[str, dict[str, Any]]] = {}

    def _bucket(self, user_id: str, application_id: str):
        self._data.setdefault(user_id, {})
        self._data[user_id].setdefault(application_id, {})
        return self._data[user_id][application_id]

    def create(self, user_id: str, application_id: str, data: dict[str, Any]) -> dict[str, Any]:
        bucket = self._bucket(user_id, application_id)
        iid = f"i{len(bucket) + 1}"
        now = datetime.now(timezone.utc)
        payload = {
            **data,
            "id": iid,
            "user_id": user_id,
            "application_id": application_id,
            "created_at": now,
            "updated_at": now,
        }
        bucket[iid] = payload
        return payload

    def get(self, user_id: str, application_id: str, interview_id: str):
        return self._data.get(user_id, {}).get(application_id, {}).get(interview_id)

    def list_for_application(self, user_id: str, application_id: str):
        return list(self._data.get(user_id, {}).get(application_id, {}).values())

    def list_all_for_user(self, user_id: str, application_ids: list[str]):
        items = []
        for aid in application_ids:
            items.extend(self.list_for_application(user_id, aid))
        return items

    def find_by_id(self, user_id: str, interview_id: str, application_ids: list[str]):
        for aid in application_ids:
            found = self.get(user_id, aid, interview_id)
            if found:
                return found
        return None

    def update(self, user_id: str, application_id: str, interview_id: str, data: dict[str, Any]):
        current = self.get(user_id, application_id, interview_id) or {}
        current.update(data)
        current["updated_at"] = datetime.now(timezone.utc)
        self._bucket(user_id, application_id)[interview_id] = current
        return current

    def delete(self, user_id: str, application_id: str, interview_id: str) -> None:
        self._data.get(user_id, {}).get(application_id, {}).pop(interview_id, None)

    def delete_all_for_application(self, user_id: str, application_id: str) -> None:
        self._data.get(user_id, {}).pop(application_id, None)


class InMemoryFollowUpRepo:
    def __init__(self) -> None:
        self._data: dict[str, dict[str, dict[str, Any]]] = {}

    def create(self, user_id: str, data: dict[str, Any]) -> dict[str, Any]:
        self._data.setdefault(user_id, {})
        fid = f"f{len(self._data[user_id]) + 1}"
        now = datetime.now(timezone.utc)
        payload = {**data, "id": fid, "user_id": user_id, "created_at": now, "updated_at": now}
        self._data[user_id][fid] = payload
        return payload

    def get(self, user_id: str, followup_id: str):
        return self._data.get(user_id, {}).get(followup_id)

    def list_all(self, user_id: str):
        return list(self._data.get(user_id, {}).values())

    def list_for_application(self, user_id: str, application_id: str):
        return [f for f in self.list_all(user_id) if f.get("application_id") == application_id]

    def update(self, user_id: str, followup_id: str, data: dict[str, Any]):
        current = self.get(user_id, followup_id) or {}
        current.update(data)
        current["updated_at"] = datetime.now(timezone.utc)
        self._data[user_id][followup_id] = current
        return current

    def delete(self, user_id: str, followup_id: str) -> None:
        self._data.get(user_id, {}).pop(followup_id, None)

    def delete_for_application(self, user_id: str, application_id: str) -> None:
        for item in list(self.list_for_application(user_id, application_id)):
            self.delete(user_id, item["id"])


@pytest.fixture
def stores():
    from app.services.activities.activity_service import ActivityService

    companies = InMemoryCompanyRepo()
    apps = InMemoryAppRepo()
    history = InMemoryHistoryRepo()
    activities = InMemoryActivityRepo()
    interviews = InMemoryInterviewRepo()
    followups = InMemoryFollowUpRepo()
    activity_svc = ActivityService(activity_repository=activities, application_repository=apps)
    company_svc = CompanyService(company_repository=companies, application_repository=apps)
    app_svc = ApplicationService(
        application_repository=apps,
        company_repository=companies,
        history_repository=history,
        activity_service=activity_svc,
        interview_repository=interviews,
        followup_repository=followups,
        activity_repository=activities,
    )
    status_svc = ApplicationStatusService(
        application_repository=apps,
        history_repository=history,
        activity_service=activity_svc,
    )
    return {
        "companies": companies,
        "apps": apps,
        "history": history,
        "activities": activities,
        "interviews": interviews,
        "followups": followups,
        "activity_svc": activity_svc,
        "company_svc": company_svc,
        "app_svc": app_svc,
        "status_svc": status_svc,
    }


def test_create_company_and_duplicate(stores):
    svc: CompanyService = stores["company_svc"]
    created = svc.create("u1", CompanyCreateRequest(name="ABC Technologies"))
    assert created.name == "ABC Technologies"
    with pytest.raises(DuplicateCompanyError):
        svc.create("u1", CompanyCreateRequest(name="abc technologies"))


def test_company_delete_blocked_with_applications(stores):
    company_svc: CompanyService = stores["company_svc"]
    app_svc: ApplicationService = stores["app_svc"]
    company = company_svc.create("u1", CompanyCreateRequest(name="Acme"))
    app_svc.create(
        "u1",
        ApplicationCreateRequest(
            company_id=company.id,
            job_title="Engineer",
            status=ApplicationStatus.APPLIED,
        ),
    )
    with pytest.raises(CompanyHasApplicationsError):
        company_svc.delete("u1", company.id)


def test_application_crud_and_status_history(stores):
    company_svc: CompanyService = stores["company_svc"]
    app_svc: ApplicationService = stores["app_svc"]
    status_svc: ApplicationStatusService = stores["status_svc"]

    company = company_svc.create("u1", CompanyCreateRequest(name="Acme"))
    created = app_svc.create(
        "u1",
        ApplicationCreateRequest(
            company_id=company.id,
            job_title="Junior Python Developer",
            location="Bangalore",
            source="LinkedIn",
            status=ApplicationStatus.APPLIED,
        ),
    )
    assert created.company.name == "Acme"
    assert created.status == ApplicationStatus.APPLIED

    history = status_svc.get_history("u1", created.id)
    assert len(history) == 1
    assert history[0].previous_status is None
    assert history[0].new_status == ApplicationStatus.APPLIED

    updated = status_svc.change_status(
        "u1",
        created.id,
        ApplicationStatusUpdateRequest(status=ApplicationStatus.HR_CALL, note="Screening done"),
    )
    assert updated.status == ApplicationStatus.HR_CALL
    history = status_svc.get_history("u1", created.id)
    assert len(history) == 2

    # unchanged status — no duplicate history
    status_svc.change_status(
        "u1",
        created.id,
        ApplicationStatusUpdateRequest(status=ApplicationStatus.HR_CALL),
    )
    assert len(status_svc.get_history("u1", created.id)) == 2

    listed = app_svc.list(user_id="u1", search="python", page=1, page_size=10)
    assert listed.total == 1

    app_svc.delete("u1", created.id)
    with pytest.raises(ApplicationNotFoundError):
        app_svc.get("u1", created.id)


def test_ownership_isolation(stores):
    company_svc: CompanyService = stores["company_svc"]
    app_svc: ApplicationService = stores["app_svc"]
    company = company_svc.create("u1", CompanyCreateRequest(name="Private Co"))
    created = app_svc.create(
        "u1",
        ApplicationCreateRequest(company_id=company.id, job_title="Role"),
    )
    with pytest.raises(ApplicationNotFoundError):
        app_svc.get("u2", created.id)
    assert app_svc.list(user_id="u2").total == 0


def test_search_filter_sort_pagination(stores):
    company_svc: CompanyService = stores["company_svc"]
    app_svc: ApplicationService = stores["app_svc"]
    c = company_svc.create("u1", CompanyCreateRequest(name="Zebra"))
    for title, status in [
        ("Python Dev", ApplicationStatus.APPLIED),
        ("React Dev", ApplicationStatus.OFFER),
        ("Python Intern", ApplicationStatus.APPLIED),
    ]:
        app_svc.create(
            "u1",
            ApplicationCreateRequest(
                company_id=c.id,
                job_title=title,
                status=status,
                source="LinkedIn",
            ),
        )

    page = app_svc.list(
        user_id="u1",
        status=["APPLIED"],
        search="python",
        sort_by="job_title",
        sort_order="asc",
        page=1,
        page_size=1,
    )
    assert page.total == 2
    assert page.has_next is True
    assert page.items[0].job_title == "Python Dev"


def test_salary_validation():
    with pytest.raises(Exception):
        ApplicationCreateRequest(
            company_id="c1",
            job_title="X",
            salary_min=10,
            salary_max=5,
        )


def test_api_applications_with_overrides(stores):
    app = create_app()
    client = TestClient(app)

    async def _claims():
        return {"uid": "u1", "email": "a@b.com"}

    import app.api.v1.dependencies as deps

    original = deps.verify_firebase_id_token

    async def _ok(_token: str):
        return {"uid": "u1", "email": "a@b.com", "name": "A", "email_verified": True}

    deps.verify_firebase_id_token = _ok  # type: ignore
    app.dependency_overrides[applications_api.get_application_service] = lambda: stores["app_svc"]
    app.dependency_overrides[applications_api.get_status_service] = lambda: stores["status_svc"]
    app.dependency_overrides[companies_api.get_company_service] = lambda: stores["company_svc"]
    # AuthService still hits Firestore on /auth/me — skip that; only test apps/companies

    try:
        company = stores["company_svc"].create("u1", CompanyCreateRequest(name="API Co"))
        response = client.post(
            "/api/v1/applications",
            headers={"Authorization": "Bearer token"},
            json={
                "company_id": company.id,
                "job_title": "Backend Engineer",
                "status": "APPLIED",
                "location": "Remote",
            },
        )
        assert response.status_code == 201, response.text
        app_id = response.json()["id"]

        listed = client.get(
            "/api/v1/applications?search=Backend",
            headers={"Authorization": "Bearer token"},
        )
        assert listed.status_code == 200
        assert listed.json()["total"] == 1

        status = client.patch(
            f"/api/v1/applications/{app_id}/status",
            headers={"Authorization": "Bearer token"},
            json={"status": "SHORTLISTED", "note": "ok"},
        )
        assert status.status_code == 200
        assert status.json()["status"] == "SHORTLISTED"

        history = client.get(
            f"/api/v1/applications/{app_id}/history",
            headers={"Authorization": "Bearer token"},
        )
        assert history.status_code == 200
        assert len(history.json()) >= 2
    finally:
        deps.verify_firebase_id_token = original
        app.dependency_overrides.clear()
