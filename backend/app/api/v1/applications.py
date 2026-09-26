"""Application CRUD and status endpoints."""

from typing import Annotated

from fastapi import APIRouter, Depends, Query

from app.api.v1.dependencies import get_current_user_id
from app.schemas.activity import ActivityResponse
from app.schemas.application import (
    ApplicationCreateRequest,
    ApplicationResponse,
    ApplicationStatusHistoryResponse,
    ApplicationStatusUpdateRequest,
    ApplicationUpdateRequest,
)
from app.schemas.interview import InterviewCreateRequest, InterviewResponse
from app.schemas.pagination import PaginatedResponse
from app.services.activities.activity_service import ActivityService
from app.services.applications.application_service import ApplicationService
from app.services.applications.application_status_service import ApplicationStatusService
from app.services.interviews.interview_service import InterviewService

router = APIRouter()


def get_application_service() -> ApplicationService:
    return ApplicationService()


def get_status_service() -> ApplicationStatusService:
    return ApplicationStatusService()


def get_interview_service() -> InterviewService:
    return InterviewService()


def get_activity_service() -> ActivityService:
    return ActivityService()


@router.post("", response_model=ApplicationResponse, status_code=201)
async def create_application(
    payload: ApplicationCreateRequest,
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[ApplicationService, Depends(get_application_service)],
) -> ApplicationResponse:
    return service.create(user_id, payload)


@router.get("", response_model=PaginatedResponse[ApplicationResponse])
async def list_applications(
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[ApplicationService, Depends(get_application_service)],
    status: Annotated[list[str] | None, Query()] = None,
    source: Annotated[list[str] | None, Query()] = None,
    employment_type: Annotated[list[str] | None, Query()] = None,
    location: Annotated[str | None, Query()] = None,
    search: Annotated[str | None, Query()] = None,
    sort_by: Annotated[str, Query()] = "created_at",
    sort_order: Annotated[str, Query()] = "desc",
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100)] = 20,
) -> PaginatedResponse[ApplicationResponse]:
    return service.list(
        user_id,
        status=status,
        source=source,
        employment_type=employment_type,
        location=location,
        search=search,
        sort_by=sort_by,
        sort_order=sort_order,
        page=page,
        page_size=page_size,
    )


@router.get("/{application_id}", response_model=ApplicationResponse)
async def get_application(
    application_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[ApplicationService, Depends(get_application_service)],
) -> ApplicationResponse:
    return service.get(user_id, application_id)


@router.patch("/{application_id}", response_model=ApplicationResponse)
async def update_application(
    application_id: str,
    payload: ApplicationUpdateRequest,
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[ApplicationService, Depends(get_application_service)],
) -> ApplicationResponse:
    return service.update(user_id, application_id, payload)


@router.delete("/{application_id}", status_code=204)
async def delete_application(
    application_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[ApplicationService, Depends(get_application_service)],
) -> None:
    service.delete(user_id, application_id)


@router.patch("/{application_id}/status", response_model=ApplicationResponse)
async def update_application_status(
    application_id: str,
    payload: ApplicationStatusUpdateRequest,
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[ApplicationStatusService, Depends(get_status_service)],
) -> ApplicationResponse:
    return service.change_status(user_id, application_id, payload)


@router.get(
    "/{application_id}/history",
    response_model=list[ApplicationStatusHistoryResponse],
)
async def get_application_history(
    application_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[ApplicationStatusService, Depends(get_status_service)],
) -> list[ApplicationStatusHistoryResponse]:
    return service.get_history(user_id, application_id)


@router.post(
    "/{application_id}/interviews",
    response_model=InterviewResponse,
    status_code=201,
)
async def create_application_interview(
    application_id: str,
    payload: InterviewCreateRequest,
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[InterviewService, Depends(get_interview_service)],
) -> InterviewResponse:
    return service.create(user_id, application_id, payload)


@router.get(
    "/{application_id}/interviews",
    response_model=list[InterviewResponse],
)
async def list_application_interviews(
    application_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[InterviewService, Depends(get_interview_service)],
) -> list[InterviewResponse]:
    return service.list_for_application(user_id, application_id)


@router.get(
    "/{application_id}/activities",
    response_model=list[ActivityResponse],
)
async def list_application_activities(
    application_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[ActivityService, Depends(get_activity_service)],
) -> list[ActivityResponse]:
    return service.list_for_application(user_id, application_id)
