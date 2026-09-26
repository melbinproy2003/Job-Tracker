"""Aggregate v1 API routers."""

from fastapi import APIRouter

from app.api.v1 import (
    applications,
    auth,
    companies,
    dashboard,
    followups,
    gmail,
    interviews,
    notifications,
    resumes,
    settings,
    users,
)

api_router = APIRouter()
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(dashboard.router, prefix="/dashboard", tags=["dashboard"])
api_router.include_router(applications.router, prefix="/applications", tags=["applications"])
api_router.include_router(companies.router, prefix="/companies", tags=["companies"])
api_router.include_router(interviews.router, prefix="/interviews", tags=["interviews"])
api_router.include_router(followups.router, prefix="/followups", tags=["followups"])
api_router.include_router(resumes.router, prefix="/resumes", tags=["resumes"])
api_router.include_router(gmail.router, prefix="/gmail", tags=["gmail"])
api_router.include_router(notifications.router, prefix="/notifications", tags=["notifications"])
api_router.include_router(settings.router, prefix="/settings", tags=["settings"])
