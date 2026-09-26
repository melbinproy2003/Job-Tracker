"""Company CRUD endpoints."""

from typing import Annotated

from fastapi import APIRouter, Depends

from app.api.v1.dependencies import get_current_user_id
from app.schemas.company import (
    CompanyCreateRequest,
    CompanyDetailResponse,
    CompanyResponse,
    CompanyUpdateRequest,
)
from app.services.companies.company_service import CompanyService

router = APIRouter()


def get_company_service() -> CompanyService:
    return CompanyService()


@router.post("", response_model=CompanyResponse, status_code=201)
async def create_company(
    payload: CompanyCreateRequest,
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[CompanyService, Depends(get_company_service)],
) -> CompanyResponse:
    return service.create(user_id, payload)


@router.get("", response_model=list[CompanyResponse])
async def list_companies(
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[CompanyService, Depends(get_company_service)],
) -> list[CompanyResponse]:
    return service.list(user_id)


@router.get("/{company_id}", response_model=CompanyDetailResponse)
async def get_company(
    company_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[CompanyService, Depends(get_company_service)],
) -> CompanyDetailResponse:
    return service.get(user_id, company_id)


@router.patch("/{company_id}", response_model=CompanyResponse)
async def update_company(
    company_id: str,
    payload: CompanyUpdateRequest,
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[CompanyService, Depends(get_company_service)],
) -> CompanyResponse:
    return service.update(user_id, company_id, payload)


@router.delete("/{company_id}", status_code=204)
async def delete_company(
    company_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[CompanyService, Depends(get_company_service)],
) -> None:
    service.delete(user_id, company_id)
