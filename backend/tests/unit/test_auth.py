"""Unit tests for auth endpoints with mocked Firebase verification."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any
from unittest.mock import MagicMock

import pytest
from fastapi.testclient import TestClient

from app.api.v1 import dependencies
from app.core.exceptions import InvalidTokenError, TokenExpiredError
from app.main import create_app
from app.schemas.auth import AuthUserResponse
from app.services.auth.auth_service import AuthService


@pytest.fixture
def app():
    return create_app()


@pytest.fixture
def client(app):
    return TestClient(app)


def test_auth_health(client: TestClient) -> None:
    response = client.get("/api/v1/auth/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_root_health(client: TestClient) -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_auth_me_missing_token(client: TestClient) -> None:
    response = client.get("/api/v1/auth/me")
    assert response.status_code == 401
    body = response.json()
    assert body["success"] is False
    assert body["error"]["code"] == "AUTHENTICATION_REQUIRED"


def test_auth_me_invalid_bearer_format(client: TestClient) -> None:
    response = client.get("/api/v1/auth/me", headers={"Authorization": "Token abc"})
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "AUTHENTICATION_REQUIRED"


def test_auth_me_invalid_token(client: TestClient, app) -> None:
    async def _boom(_token: str) -> dict[str, Any]:
        raise InvalidTokenError()

    app.dependency_overrides[dependencies.verify_firebase_id_token] = None

    # Override at module used by dependencies
    import app.api.v1.dependencies as deps

    original = deps.verify_firebase_id_token
    deps.verify_firebase_id_token = _boom  # type: ignore[assignment]
    try:
        response = client.get(
            "/api/v1/auth/me",
            headers={"Authorization": "Bearer invalid-token"},
        )
        assert response.status_code == 401
        assert response.json()["error"]["code"] == "INVALID_TOKEN"
    finally:
        deps.verify_firebase_id_token = original


def test_auth_me_expired_token(client: TestClient) -> None:
    import app.api.v1.dependencies as deps

    async def _expired(_token: str) -> dict[str, Any]:
        raise TokenExpiredError()

    original = deps.verify_firebase_id_token
    deps.verify_firebase_id_token = _expired  # type: ignore[assignment]
    try:
        response = client.get(
            "/api/v1/auth/me",
            headers={"Authorization": "Bearer expired-token"},
        )
        assert response.status_code == 401
        assert response.json()["error"]["code"] == "TOKEN_EXPIRED"
    finally:
        deps.verify_firebase_id_token = original


def test_auth_me_valid_token_creates_user(client: TestClient) -> None:
    import app.api.v1.dependencies as deps

    claims = {
        "uid": "firebase-uid-1",
        "email": "melbin@example.com",
        "name": "Melbin P Roy",
        "picture": "https://example.com/photo.jpg",
        "email_verified": True,
    }

    async def _ok(_token: str) -> dict[str, Any]:
        return claims

    mock_repo = MagicMock()
    mock_repo.upsert_from_claims.return_value = {
        "id": "firebase-uid-1",
        "email": "melbin@example.com",
        "display_name": "Melbin P Roy",
        "photo_url": "https://example.com/photo.jpg",
        "email_verified": True,
        "created_at": datetime.now(timezone.utc),
        "updated_at": datetime.now(timezone.utc),
        "last_login_at": datetime.now(timezone.utc),
    }

    original_verify = deps.verify_firebase_id_token
    original_service = deps.get_auth_service
    deps.verify_firebase_id_token = _ok  # type: ignore[assignment]
    deps.get_auth_service = lambda: AuthService(user_repository=mock_repo)
    try:
        response = client.get(
            "/api/v1/auth/me",
            headers={"Authorization": "Bearer valid-token"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == "firebase-uid-1"
        assert data["email"] == "melbin@example.com"
        assert data["display_name"] == "Melbin P Roy"
        assert data["photo_url"] == "https://example.com/photo.jpg"
        assert data["email_verified"] is True
        mock_repo.upsert_from_claims.assert_called_once()
        # Ensure client-supplied user_id is never used — only claims uid
        assert mock_repo.upsert_from_claims.call_args[0][0] == "firebase-uid-1"
    finally:
        deps.verify_firebase_id_token = original_verify
        deps.get_auth_service = original_service


def test_auth_service_maps_claims() -> None:
    mock_repo = MagicMock()
    mock_repo.upsert_from_claims.return_value = {
        "id": "uid-2",
        "email": "a@b.com",
        "display_name": "A",
        "photo_url": None,
        "email_verified": False,
    }
    service = AuthService(user_repository=mock_repo)
    result = service.get_me(
        "uid-2",
        {"uid": "uid-2", "email": "a@b.com", "name": "A", "email_verified": False},
    )
    assert isinstance(result, AuthUserResponse)
    assert result.id == "uid-2"
