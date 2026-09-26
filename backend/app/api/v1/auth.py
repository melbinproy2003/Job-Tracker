"""Authentication endpoints (Google SSO via Firebase — no password login)."""

from fastapi import APIRouter, Depends

from app.api.v1.dependencies import get_current_user
from app.schemas.auth import AuthHealthResponse, AuthUserResponse

router = APIRouter()


@router.get("/health", response_model=AuthHealthResponse)
async def auth_health() -> AuthHealthResponse:
    """Lightweight auth-module health check (no authentication required)."""
    return AuthHealthResponse(status="ok")


@router.get("/me", response_model=AuthUserResponse)
async def get_me(user: AuthUserResponse = Depends(get_current_user)) -> AuthUserResponse:
    """Return the authenticated user profile.

    Identity always comes from the verified Firebase ID token.
    """
    return user
