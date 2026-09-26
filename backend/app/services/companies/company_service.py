"""Company business logic."""

from __future__ import annotations

from typing import Any

from app.core.exceptions import (
    CompanyHasApplicationsError,
    CompanyNotFoundError,
    DuplicateCompanyError,
    ValidationError,
)
from app.repositories.application_repository import ApplicationRepository
from app.repositories.company_repository import CompanyRepository
from app.schemas.company import (
    CompanyCreateRequest,
    CompanyDetailResponse,
    CompanyResponse,
    CompanyUpdateRequest,
)
from app.utils.text import sanitize_text


class CompanyService:
    def __init__(
        self,
        company_repository: CompanyRepository | None = None,
        application_repository: ApplicationRepository | None = None,
    ):
        self._companies = company_repository or CompanyRepository()
        self._applications = application_repository or ApplicationRepository()

    def create(self, user_id: str, payload: CompanyCreateRequest) -> CompanyResponse:
        existing = self._companies.find_by_normalized_name(user_id, payload.name)
        if existing:
            raise DuplicateCompanyError()
        data = {
            "name": payload.name,
            "website": payload.website,
            "location": sanitize_text(payload.location),
            "industry": sanitize_text(payload.industry),
            "notes": sanitize_text(payload.notes),
        }
        created = self._companies.create(user_id, data)
        return self._to_response(created, application_count=0)

    def list(self, user_id: str) -> list[CompanyResponse]:
        companies = self._companies.list(user_id)
        result: list[CompanyResponse] = []
        for company in companies:
            count = self._applications.count_by_company(user_id, company["id"])
            result.append(self._to_response(company, application_count=count))
        return result

    def get(self, user_id: str, company_id: str) -> CompanyDetailResponse:
        company = self._companies.get(user_id, company_id)
        if not company:
            raise CompanyNotFoundError()
        apps = self._applications.list_by_company(user_id, company_id)
        app_summaries = [
            {
                "id": a["id"],
                "job_title": a.get("job_title"),
                "status": a.get("status"),
                "applied_at": a.get("applied_at"),
            }
            for a in apps
        ]
        base = self._to_response(company, application_count=len(apps))
        return CompanyDetailResponse(**base.model_dump(), applications=app_summaries)

    def update(
        self, user_id: str, company_id: str, payload: CompanyUpdateRequest
    ) -> CompanyResponse:
        company = self._companies.get(user_id, company_id)
        if not company:
            raise CompanyNotFoundError()
        updates = payload.model_dump(exclude_unset=True)
        if "name" in updates and updates["name"]:
            dup = self._companies.find_by_normalized_name(user_id, updates["name"])
            if dup and dup["id"] != company_id:
                raise DuplicateCompanyError()
        if "location" in updates:
            updates["location"] = sanitize_text(updates.get("location"))
        if "industry" in updates:
            updates["industry"] = sanitize_text(updates.get("industry"))
        if "notes" in updates:
            updates["notes"] = sanitize_text(updates.get("notes"))
        updated = self._companies.update(user_id, company_id, updates)
        count = self._applications.count_by_company(user_id, company_id)
        return self._to_response(updated, application_count=count)

    def delete(self, user_id: str, company_id: str) -> None:
        company = self._companies.get(user_id, company_id)
        if not company:
            raise CompanyNotFoundError()
        count = self._applications.count_by_company(user_id, company_id)
        if count > 0:
            raise CompanyHasApplicationsError(
                f"This company has {count} applications and cannot be deleted."
            )
        self._companies.delete(user_id, company_id)

    @staticmethod
    def _to_response(data: dict[str, Any], *, application_count: int) -> CompanyResponse:
        return CompanyResponse(
            id=data["id"],
            name=data.get("name") or "",
            website=data.get("website"),
            location=data.get("location"),
            industry=data.get("industry"),
            notes=data.get("notes"),
            application_count=application_count,
            created_at=data.get("created_at"),
            updated_at=data.get("updated_at"),
        )
