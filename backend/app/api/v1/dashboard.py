"""Dashboard aggregate endpoints."""

from typing import Annotated

from fastapi import APIRouter, Depends

from app.api.v1.dependencies import get_current_user_id
from app.schemas.dashboard import DashboardResponse
from app.services.dashboard.dashboard_service import DashboardService

router = APIRouter()


def get_dashboard_service() -> DashboardService:
    return DashboardService()


@router.get("", response_model=DashboardResponse)
async def get_dashboard(
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[DashboardService, Depends(get_dashboard_service)],
) -> DashboardResponse:
    return service.get_dashboard(user_id)
