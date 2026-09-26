"""Follow-up endpoints."""

from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, Query

from app.api.v1.dependencies import get_current_user_id
from app.schemas.followup import FollowUpCreateRequest, FollowUpResponse, FollowUpUpdateRequest
from app.services.followups.followup_service import FollowUpService

router = APIRouter()


def get_followup_service() -> FollowUpService:
    return FollowUpService()


@router.post("", response_model=FollowUpResponse, status_code=201)
async def create_followup(
    payload: FollowUpCreateRequest,
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[FollowUpService, Depends(get_followup_service)],
) -> FollowUpResponse:
    return service.create(user_id, payload)


@router.get("", response_model=list[FollowUpResponse])
async def list_followups(
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[FollowUpService, Depends(get_followup_service)],
    completed: Annotated[bool | None, Query()] = None,
    from_: Annotated[datetime | None, Query(alias="from")] = None,
    to: Annotated[datetime | None, Query()] = None,
    application_id: Annotated[str | None, Query()] = None,
) -> list[FollowUpResponse]:
    return service.list(
        user_id,
        completed=completed,
        from_date=from_,
        to_date=to,
        application_id=application_id,
    )


@router.get("/{followup_id}", response_model=FollowUpResponse)
async def get_followup(
    followup_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[FollowUpService, Depends(get_followup_service)],
) -> FollowUpResponse:
    return service.get(user_id, followup_id)


@router.patch("/{followup_id}", response_model=FollowUpResponse)
async def update_followup(
    followup_id: str,
    payload: FollowUpUpdateRequest,
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[FollowUpService, Depends(get_followup_service)],
) -> FollowUpResponse:
    return service.update(user_id, followup_id, payload)


@router.patch("/{followup_id}/complete", response_model=FollowUpResponse)
async def complete_followup(
    followup_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[FollowUpService, Depends(get_followup_service)],
) -> FollowUpResponse:
    return service.complete(user_id, followup_id)


@router.delete("/{followup_id}", status_code=204)
async def delete_followup(
    followup_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[FollowUpService, Depends(get_followup_service)],
) -> None:
    service.delete(user_id, followup_id)
