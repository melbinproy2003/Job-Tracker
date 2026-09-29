"""Gmail OAuth connect / token refresh (encrypted at rest)."""

from __future__ import annotations

import logging
import secrets
from datetime import datetime, timezone
from typing import Any
from urllib.parse import urlencode

from app.core.config import get_settings
from app.core.exceptions import AppError, ValidationError
from app.integrations.google.gmail_client import GoogleGmailClient
from app.integrations.google.oauth_client import (
    GoogleOAuthClient,
    generate_code_verifier,
)
from app.repositories.gmail_account_repository import GmailAccountRepository
from app.repositories.oauth_state_repository import OAuthStateRepository
from app.utils.encryption import decrypt_secret, encrypt_secret

logger = logging.getLogger(__name__)

# Deep-link error codes only — never raw OAuth library messages.
_SAFE_ERROR_CODES = frozenset(
    {
        "oauth_failed",
        "oauth_cancelled",
        "oauth_denied",
        "invalid_state",
        "token_exchange_failed",
        "gmail_not_configured",
    }
)


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
            raise AppError(
                "Gmail OAuth is not configured.", code="GMAIL_NOT_CONFIGURED", status_code=503
            )
        state = secrets.token_urlsafe(24)
        code_verifier = generate_code_verifier()
        self._states.save(state, user_id, code_verifier=code_verifier)
        return self._oauth.build_authorization_url(state, code_verifier=code_verifier)

    def handle_callback(
        self,
        *,
        code: str | None,
        state: str | None,
        oauth_error: str | None = None,
    ) -> dict[str, Any]:
        # User cancelled / denied on Google's consent screen.
        if oauth_error:
            logger.info("Gmail OAuth provider error: %s", oauth_error[:80])
            if oauth_error in ("access_denied", "user_cancelled"):
                raise ValidationError(
                    "Gmail connection cancelled.",
                    code="OAUTH_CANCELLED",
                )
            raise ValidationError(
                "Gmail authorization was denied.",
                code="OAUTH_DENIED",
            )

        if not code or not state:
            raise ValidationError("Missing OAuth code or state.", code="INVALID_OAUTH_CALLBACK")

        pending = self._states.consume(state)
        if not pending:
            raise ValidationError("Invalid or expired OAuth state.", code="INVALID_OAUTH_STATE")
        if not pending.code_verifier:
            # Should be unreachable after consume() validation; keep explicit.
            raise ValidationError(
                "Missing PKCE code verifier for this OAuth state.",
                code="MISSING_CODE_VERIFIER",
            )

        try:
            tokens = self._oauth.exchange_code(code, code_verifier=pending.code_verifier)
        except Exception as exc:
            # Log type + message (no tokens/codes). Warning often means oauthlib
            # scope mismatch when Google returns extra granted scopes.
            logger.warning(
                "Gmail token exchange failed: %s: %s",
                type(exc).__name__,
                str(exc)[:200],
            )
            raise AppError(
                "Google could not complete the Gmail authorization.",
                code="GMAIL_TOKEN_EXCHANGE_FAILED",
                status_code=502,
            ) from exc

        access = tokens.get("access_token")
        refresh = tokens.get("refresh_token")
        if not access:
            raise AppError(
                "Failed to obtain Gmail access token.",
                code="GMAIL_TOKEN_ERROR",
                status_code=502,
            )

        client = GoogleGmailClient(access, refresh)
        email = client.get_profile_email()
        if not email:
            raise AppError(
                "Unable to read Gmail profile.",
                code="GMAIL_PROFILE_ERROR",
                status_code=502,
            )

        encrypted_access = encrypt_secret(access)
        encrypted_refresh = encrypt_secret(refresh) if refresh else None
        account = self._accounts.upsert_by_email(
            pending.user_id,
            email,
            {
                "encrypted_access_token": encrypted_access,
                "encrypted_refresh_token": encrypted_refresh,
                "token_expires_at": tokens.get("token_expires_at"),
                "scopes": tokens.get("scopes") or [],
                "connected": True,
            },
        )
        return {"user_id": pending.user_id, "account": account, "email": email}

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

    def frontend_redirect(
        self, *, success: bool, email: str | None = None, error: str | None = None
    ) -> str:
        settings = get_settings()
        if success:
            base = settings.gmail_frontend_success_url
            # Optional display hint only — never tokens or verifier.
            params = {}
            if email:
                params["email"] = email
            return f"{base}?{urlencode(params)}" if params else base
        base = settings.gmail_frontend_error_url
        safe = self._safe_error_code(error)
        return f"{base}?{urlencode({'error': safe})}"

    @staticmethod
    def _safe_error_code(error: str | None) -> str:
        if not error:
            return "oauth_failed"
        normalized = error.strip().lower().replace(" ", "_")
        if normalized in _SAFE_ERROR_CODES:
            return normalized
        # Map known AppError / ValidationError codes.
        code_map = {
            "oauth_cancelled": "oauth_cancelled",
            "oauth_denied": "oauth_denied",
            "invalid_oauth_state": "invalid_state",
            "invalid_oauth_callback": "oauth_failed",
            "missing_code_verifier": "token_exchange_failed",
            "gmail_token_exchange_failed": "token_exchange_failed",
            "gmail_token_error": "token_exchange_failed",
            "gmail_not_configured": "gmail_not_configured",
        }
        return code_map.get(normalized, "oauth_failed")
