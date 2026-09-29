"""Authentication and user bootstrap service."""

from __future__ import annotations

from typing import Any

from app.repositories.user_repository import UserRepository
from app.schemas.auth import AuthUserResponse


class AuthService:
    def __init__(self, user_repository: UserRepository | None = None):
        self._users = user_repository or UserRepository()

    def get_or_create_user(self, user_id: str, claims: dict[str, Any]) -> AuthUserResponse:
        """Upsert user from verified Firebase claims and return API response."""
        profile = {
            "email": claims.get("email"),
            "display_name": claims.get("name") or claims.get("display_name"),
            "photo_url": claims.get("picture") or claims.get("photo_url"),
            "email_verified": bool(claims.get("email_verified", False)),
        }
        user = self._users.upsert_from_claims(user_id, profile)
        return self._to_response(user)

    def get_me(self, user_id: str, claims: dict[str, Any]) -> AuthUserResponse:
        """Ensure user exists and return current profile."""
        return self.get_or_create_user(user_id, claims)

    @staticmethod
    def _to_response(user: dict[str, Any]) -> AuthUserResponse:
        return AuthUserResponse(
            id=str(user["id"]),
            email=user.get("email"),
            display_name=user.get("display_name"),
            photo_url=user.get("photo_url"),
            email_verified=bool(user.get("email_verified", False)),
        )
