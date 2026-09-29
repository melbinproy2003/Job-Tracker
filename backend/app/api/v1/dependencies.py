"""API dependencies: auth, current user."""

from __future__ import annotations

from typing import Annotated, Any

from fastapi import Depends, Header

from app.core.exceptions import AuthenticationError
from app.core.security import get_user_id_from_claims, verify_firebase_id_token
from app.schemas.auth import AuthUserResponse
from app.services.auth.auth_service import AuthService


def get_auth_service() -> AuthService:
    return AuthService()


async def get_current_user_claims(
    authorization: Annotated[str | None, Header()] = None,
) -> dict[str, Any]:
    """Verify Bearer Firebase ID token and return claims."""
    if not authorization or not authorization.startswith("Bearer "):
        raise AuthenticationError("Authentication is required.")

    token = authorization.removeprefix("Bearer ").strip()
    if not token:
        raise AuthenticationError("Authentication is required.")

    return await verify_firebase_id_token(token)


async def get_current_user_id(
    claims: Annotated[dict[str, Any], Depends(get_current_user_claims)],
) -> str:
    """Derive user_id exclusively from verified Firebase claims."""
    return get_user_id_from_claims(claims)


async def get_current_user(
    claims: Annotated[dict[str, Any], Depends(get_current_user_claims)],
    auth_service: Annotated[AuthService, Depends(get_auth_service)],
) -> AuthUserResponse:
    """Return the authenticated user, creating/updating Firestore profile as needed."""
    user_id = get_user_id_from_claims(claims)
    return auth_service.get_me(user_id, claims)
