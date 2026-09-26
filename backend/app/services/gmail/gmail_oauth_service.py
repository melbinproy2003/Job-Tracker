"""Gmail OAuth connect / token refresh (encrypted at rest)."""

from __future__ import annotations

import secrets
from datetime import datetime, timezone
from typing import Any
from urllib.parse import urlencode

from app.core.config import get_settings
from app.core.exceptions import AppError, ValidationError
from app.integrations.google.gmail_client import GoogleGmailClient
from app.integrations.google.oauth_client import GoogleOAuthClient
from app.repositories.gmail_account_repository import GmailAccountRepository
from app.repositories.oauth_state_repository import OAuthStateRepository
from app.utils.encryption import decrypt_secret, encrypt_secret


class GmailOAuthService:
    def __init__(
        self,
        account_repository: GmailAccountRepository | None = None,
        state_repository: OAuthStateRepository | None = None,
        oauth_client: GoogleOAuthClient | None = None,
    ):
        self._accounts = account_repository or GmailAccountRepository()
        self._states = state_repository or OAuthStateRepository()
        self._oauth = oauth_client or GoogleOAuthClient()

    def build_authorization_url(self, user_id: str) -> str:
        settings = get_settings()
        if not settings.google_client_id or not settings.google_client_secret:
            raise AppError("Gmail OAuth is not configured.", code="GMAIL_NOT_CONFIGURED", status_code=503)
        state = secrets.token_urlsafe(24)
        self._states.save(state, user_id)
        return self._oauth.build_authorization_url(state)

    def handle_callback(self, *, code: str | None, state: str | None) -> dict[str, Any]:
        if not code or not state:
            raise ValidationError("Missing OAuth code or state.", code="INVALID_OAUTH_CALLBACK")
        user_id = self._states.consume(state)
        if not user_id:
            raise ValidationError("Invalid or expired OAuth state.", code="INVALID_OAUTH_STATE")

        tokens = self._oauth.exchange_code(code)
        access = tokens.get("access_token")
        refresh = tokens.get("refresh_token")
        if not access:
            raise AppError("Failed to obtain Gmail access token.", code="GMAIL_TOKEN_ERROR", status_code=502)

        client = GoogleGmailClient(access, refresh)
        email = client.get_profile_email()
        if not email:
            raise AppError("Unable to read Gmail profile.", code="GMAIL_PROFILE_ERROR", status_code=502)

        encrypted_access = encrypt_secret(access)
        encrypted_refresh = encrypt_secret(refresh) if refresh else None
        account = self._accounts.upsert_by_email(
            user_id,
            email,
            {
                "encrypted_access_token": encrypted_access,
                "encrypted_refresh_token": encrypted_refresh,
                "token_expires_at": tokens.get("token_expires_at"),
                "scopes": tokens.get("scopes") or [],
                "connected": True,
            },
        )
        return {"user_id": user_id, "account": account, "email": email}

    def get_valid_access_token(self, user_id: str, account: dict[str, Any]) -> str:
        access_enc = account.get("encrypted_access_token")
        refresh_enc = account.get("encrypted_refresh_token")
        expires = account.get("token_expires_at")
        now = datetime.now(timezone.utc)

        access = decrypt_secret(access_enc) if access_enc else None
        if access and expires:
            exp = expires if expires.tzinfo else expires.replace(tzinfo=timezone.utc)
            if exp > now:
                return access

        if not refresh_enc:
            raise AppError(
                "Gmail authorization expired. Please reconnect Gmail.",
                code="GMAIL_REAUTH_REQUIRED",
                status_code=401,
            )
        refresh = decrypt_secret(refresh_enc)
        refreshed = self._oauth.refresh_access_token(refresh)
        new_access = refreshed["access_token"]
        self._accounts.update(
            user_id,
            account["id"],
            {
                "encrypted_access_token": encrypt_secret(new_access),
                "encrypted_refresh_token": encrypt_secret(
                    refreshed.get("refresh_token") or refresh
                ),
                "token_expires_at": refreshed.get("token_expires_at"),
            },
        )
        return new_access

    def frontend_redirect(self, *, success: bool, email: str | None = None, error: str | None = None) -> str:
        settings = get_settings()
        if success:
            base = settings.gmail_frontend_success_url
            return f"{base}?{urlencode({'email': email or ''})}"
        base = settings.gmail_frontend_error_url
        return f"{base}?{urlencode({'error': error or 'oauth_failed'})}"
