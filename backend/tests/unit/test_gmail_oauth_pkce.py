"""PKCE + OAuth state regression tests for Gmail connect/callback."""

from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone
from typing import Any
from unittest.mock import MagicMock
from urllib.parse import parse_qs, urlparse

import pytest

from app.core.exceptions import ValidationError
from app.integrations.google.oauth_client import (
    GoogleOAuthClient,
    code_challenge_s256,
    generate_code_verifier,
)
from app.repositories.oauth_state_repository import (
    OAuthStateRepository,
    PendingOAuthState,
)
from app.services.gmail.gmail_oauth_service import GmailOAuthService


class _MemoryStateRepo:
    """In-memory stand-in for Firestore OAuth state documents."""

    def __init__(self) -> None:
        self._data: dict[str, dict[str, Any]] = {}

    def save(
        self,
        state: str,
        user_id: str,
        *,
        code_verifier: str,
        ttl_minutes: int = 15,
    ) -> None:
        if not code_verifier:
            raise ValueError("code_verifier is required when saving OAuth state")
        self._data[state] = {
            "user_id": user_id,
            "code_verifier": code_verifier,
            "expires_at": datetime.now(timezone.utc) + timedelta(minutes=ttl_minutes),
            "used": False,
        }

    def consume(self, state: str) -> PendingOAuthState | None:
        data = self._data.pop(state, None)
        if not data:
            return None
        if data.get("used"):
            return None
        expires = data.get("expires_at")
        if expires and expires < datetime.now(timezone.utc):
            return None
        user_id = data.get("user_id")
        code_verifier = data.get("code_verifier")
        if not user_id or not code_verifier:
            return None
        return PendingOAuthState(user_id=str(user_id), code_verifier=str(code_verifier))


def test_generate_code_verifier_length_and_alphabet():
    verifier = generate_code_verifier(64)
    assert len(verifier) == 64
    assert code_challenge_s256(verifier)
    # Challenge must not include padding.
    assert "=" not in code_challenge_s256(verifier)


def test_connect_stores_verifier_and_auth_url_includes_challenge(monkeypatch):
    states = _MemoryStateRepo()
    captured: dict[str, Any] = {}

    class _FakeOAuth:
        def build_authorization_url(self, state: str, *, code_verifier: str) -> str:
            captured["state"] = state
            captured["code_verifier"] = code_verifier
            challenge = code_challenge_s256(code_verifier)
            return (
                "https://accounts.google.com/o/oauth2/auth?"
                f"state={state}&code_challenge={challenge}&code_challenge_method=S256"
            )

        def exchange_code(self, code: str, *, code_verifier: str):
            raise AssertionError("should not exchange during connect")

    monkeypatch.setenv("GOOGLE_CLIENT_ID", "cid")
    monkeypatch.setenv("GOOGLE_CLIENT_SECRET", "csecret")
    # Reset settings cache if present.
    from app.core import config

    get_settings = getattr(config, "get_settings", None)
    if get_settings and hasattr(get_settings, "cache_clear"):
        get_settings.cache_clear()

    svc = GmailOAuthService(
        account_repository=MagicMock(),
        state_repository=states,  # type: ignore[arg-type]
        oauth_client=_FakeOAuth(),  # type: ignore[arg-type]
    )
    # Bypass config check if client id already set in env; otherwise patch settings.
    monkeypatch.setattr(
        "app.services.gmail.gmail_oauth_service.get_settings",
        lambda: MagicMock(
            google_client_id="cid",
            google_client_secret="sec",
            gmail_frontend_success_url="jobtracker://gmail/connected",
            gmail_frontend_error_url="jobtracker://gmail/error",
        ),
    )

    url = svc.build_authorization_url("user-1")
    parsed = urlparse(url)
    qs = parse_qs(parsed.query)

    assert "code_challenge" in qs
    assert qs["code_challenge_method"] == ["S256"]
    assert captured["code_verifier"]
    pending = states.consume(captured["state"])
    assert pending is not None
    assert pending.user_id == "user-1"
    assert pending.code_verifier == captured["code_verifier"]
    # Challenge matches stored verifier.
    assert qs["code_challenge"][0] == code_challenge_s256(pending.code_verifier)


def test_callback_passes_stored_verifier_to_token_exchange(monkeypatch):
    states = _MemoryStateRepo()
    verifier = generate_code_verifier()
    states.save("st1", "user-1", code_verifier=verifier)
    exchanged: dict[str, Any] = {}

    class _FakeOAuth:
        def exchange_code(self, code: str, *, code_verifier: str):
            exchanged["code"] = code
            exchanged["code_verifier"] = code_verifier
            return {
                "access_token": "access",
                "refresh_token": "refresh",
                "token_expires_at": datetime.now(timezone.utc),
                "scopes": [],
            }

    accounts = MagicMock()
    accounts.upsert_by_email.return_value = {"id": "acc1", "email": "a@b.com"}

    svc = GmailOAuthService(
        account_repository=accounts,
        state_repository=states,  # type: ignore[arg-type]
        oauth_client=_FakeOAuth(),  # type: ignore[arg-type]
    )

    from app.services.gmail import gmail_oauth_service as mod

    class _Profile:
        def get_profile_email(self):
            return "a@b.com"

    monkeypatch.setattr(mod, "GoogleGmailClient", lambda *a, **k: _Profile())
    monkeypatch.setattr(mod, "encrypt_secret", lambda x: f"enc:{x}")

    result = svc.handle_callback(code="auth-code", state="st1")

    assert exchanged["code"] == "auth-code"
    assert exchanged["code_verifier"] == verifier
    assert result["email"] == "a@b.com"
    assert states.consume("st1") is None


def test_callback_rejects_missing_verifier_in_state():
    states = _MemoryStateRepo()
    # Simulate legacy / corrupt document without verifier.
    states._data["st2"] = {
        "user_id": "user-1",
        "code_verifier": "",
        "expires_at": datetime.now(timezone.utc) + timedelta(minutes=10),
        "used": False,
    }

    class _FakeOAuth:
        def exchange_code(self, code: str, *, code_verifier: str):
            raise AssertionError("must not exchange without verifier")

    svc = GmailOAuthService(
        account_repository=MagicMock(),
        state_repository=states,  # type: ignore[arg-type]
        oauth_client=_FakeOAuth(),  # type: ignore[arg-type]
    )
    with pytest.raises(ValidationError) as exc:
        svc.handle_callback(code="auth-code", state="st2")
    assert exc.value.code == "INVALID_OAUTH_STATE"


def test_callback_rejects_expired_and_used_and_invalid_state():
    states = _MemoryStateRepo()
    svc = GmailOAuthService(
        account_repository=MagicMock(),
        state_repository=states,  # type: ignore[arg-type]
        oauth_client=MagicMock(),
    )

    with pytest.raises(ValidationError) as exc:
        svc.handle_callback(code="c", state="missing")
    assert exc.value.code == "INVALID_OAUTH_STATE"

    # Expired
    states._data["exp"] = {
        "user_id": "u",
        "code_verifier": "v" * 43,
        "expires_at": datetime.now(timezone.utc) - timedelta(minutes=1),
        "used": False,
    }
    with pytest.raises(ValidationError):
        svc.handle_callback(code="c", state="exp")

    # Already marked used
    states._data["used"] = {
        "user_id": "u",
        "code_verifier": "v" * 43,
        "expires_at": datetime.now(timezone.utc) + timedelta(minutes=10),
        "used": True,
    }
    with pytest.raises(ValidationError):
        svc.handle_callback(code="c", state="used")


def test_callback_user_cancelled():
    svc = GmailOAuthService(
        account_repository=MagicMock(),
        state_repository=_MemoryStateRepo(),  # type: ignore[arg-type]
        oauth_client=MagicMock(),
    )
    with pytest.raises(ValidationError) as exc:
        svc.handle_callback(code=None, state=None, oauth_error="access_denied")
    assert exc.value.code == "OAUTH_CANCELLED"


def test_exchange_code_requires_verifier():
    client = GoogleOAuthClient()
    with pytest.raises(ValueError, match="code_verifier"):
        client.exchange_code("code", code_verifier="")
    with pytest.raises(ValueError, match="code_verifier"):
        client.build_authorization_url("st", code_verifier="")


def test_exchange_code_relaxes_oauthlib_scope_env(monkeypatch):
    """Google may return extra scopes; oauthlib must not abort as Warning."""
    seen: dict[str, str | None] = {}

    class _FakeFlow:
        code_verifier = "v"

        def fetch_token(self, code=None):
            seen["env"] = os.environ.get("OAUTHLIB_RELAX_TOKEN_SCOPE")
            self.credentials = MagicMock(
                token="access",
                refresh_token="refresh",
                expiry=None,
                scopes=["https://www.googleapis.com/auth/gmail.readonly", "profile"],
                id_token=None,
            )

    monkeypatch.setattr(
        GoogleOAuthClient,
        "_flow",
        lambda self, *, code_verifier: _FakeFlow(),
    )
    monkeypatch.delenv("OAUTHLIB_RELAX_TOKEN_SCOPE", raising=False)

    client = GoogleOAuthClient()
    result = client.exchange_code("auth-code", code_verifier="v" * 43)
    assert seen["env"] == "1"
    assert result["access_token"] == "access"
    assert os.environ.get("OAUTHLIB_RELAX_TOKEN_SCOPE") is None


def test_frontend_redirect_never_leaks_raw_errors():
    svc = GmailOAuthService(
        account_repository=MagicMock(),
        state_repository=_MemoryStateRepo(),  # type: ignore[arg-type]
        oauth_client=MagicMock(),
    )
    from unittest.mock import MagicMock as M

    # Patch settings via attribute access in method
    import app.services.gmail.gmail_oauth_service as mod

    mod.get_settings = lambda: M(  # type: ignore[assignment]
        gmail_frontend_success_url="jobtracker://gmail/connected",
        gmail_frontend_error_url="jobtracker://gmail/error",
    )
    url = svc.frontend_redirect(
        success=False,
        error="(invalid_grant) Missing code verifier",
    )
    assert "code_verifier" not in url.lower()
    assert "invalid_grant" not in url.lower()
    assert "error=oauth_failed" in url


def test_oauth_state_repository_consume_contract_with_mock_firestore():
    """Document-shaped consume matches PendingOAuthState."""
    repo = OAuthStateRepository(client=MagicMock())
    # Use memory via monkeypatch of _col
    store: dict[str, Any] = {}

    class _Doc:
        def __init__(self, key: str):
            self.key = key

        def set(self, data):
            store[self.key] = dict(data)

        def get(self):
            snap = MagicMock()
            if self.key not in store:
                snap.exists = False
                snap.to_dict.return_value = None
                return snap
            snap.exists = True
            snap.to_dict.return_value = store[self.key]
            return snap

        def delete(self):
            store.pop(self.key, None)

    class _Col:
        def document(self, key: str):
            return _Doc(key)

    repo._col = lambda: _Col()  # type: ignore[method-assign]
    verifier = generate_code_verifier()
    repo.save("s1", "u1", code_verifier=verifier)
    pending = repo.consume("s1")
    assert pending == PendingOAuthState(user_id="u1", code_verifier=verifier)
    assert repo.consume("s1") is None
