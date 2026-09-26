"""Interview CRUD endpoints."""

from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, Query

from app.api.v1.dependencies import get_current_user_id
from app.schemas.interview import InterviewCreateRequest, InterviewResponse, InterviewUpdateRequest
from app.services.interviews.interview_service import InterviewService

router = APIRouter()


def get_interview_service() -> InterviewService:
    return InterviewService()


@router.get("", response_model=list[InterviewResponse])
async def list_interviews(
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[InterviewService, Depends(get_interview_service)],
    status: Annotated[str | None, Query()] = None,
    from_: Annotated[datetime | None, Query(alias="from")] = None,
    to: Annotated[datetime | None, Query()] = None,
    application_id: Annotated[str | None, Query()] = None,
) -> list[InterviewResponse]:
    return service.list(
        user_id,
        status=status,
        from_date=from_,
        to_date=to,
        application_id=application_id,
    )


@router.get("/{interview_id}", response_model=InterviewResponse)
async def get_interview(
    interview_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[InterviewService, Depends(get_interview_service)],
) -> InterviewResponse:
    return service.get(user_id, interview_id)


@router.patch("/{interview_id}", response_model=InterviewResponse)
async def update_interview(
    interview_id: str,
    payload: InterviewUpdateRequest,
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[InterviewService, Depends(get_interview_service)],
) -> InterviewResponse:
    return service.update(user_id, interview_id, payload)


@router.delete("/{interview_id}", status_code=204)
async def delete_interview(
    interview_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[InterviewService, Depends(get_interview_service)],
) -> None:
    service.delete(user_id, interview_id)
