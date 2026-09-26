"""Google OAuth helpers for Gmail (backend-only)."""

from __future__ import annotations

from typing import Any

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import Flow

from app.core.config import get_settings

GMAIL_SCOPES = [
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/userinfo.email",
    "openid",
]


class GoogleOAuthClient:
    def build_authorization_url(self, state: str) -> str:
        flow = self._flow()
        auth_url, _ = flow.authorization_url(
            access_type="offline",
            include_granted_scopes="true",
            prompt="consent",
            state=state,
        )
        return auth_url

    def exchange_code(self, code: str) -> dict[str, Any]:
        flow = self._flow()
        flow.fetch_token(code=code)
        creds = flow.credentials
        return {
            "access_token": creds.token,
            "refresh_token": creds.refresh_token,
            "token_expires_at": creds.expiry,
            "scopes": list(creds.scopes or GMAIL_SCOPES),
            "id_token": getattr(creds, "id_token", None),
        }

    def refresh_access_token(self, refresh_token: str) -> dict[str, Any]:
        settings = get_settings()
        creds = Credentials(
            token=None,
            refresh_token=refresh_token,
            token_uri="https://oauth2.googleapis.com/token",
            client_id=settings.google_client_id,
            client_secret=settings.google_client_secret,
            scopes=GMAIL_SCOPES,
        )
        creds.refresh(Request())
        return {
            "access_token": creds.token,
            "refresh_token": creds.refresh_token or refresh_token,
            "token_expires_at": creds.expiry,
            "scopes": list(creds.scopes or GMAIL_SCOPES),
        }

    def _flow(self) -> Flow:
        settings = get_settings()
        if not settings.google_client_id or not settings.google_client_secret:
            raise RuntimeError("Google OAuth client is not configured.")
        client_config = {
            "web": {
                "client_id": settings.google_client_id,
                "client_secret": settings.google_client_secret,
                "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                "token_uri": "https://oauth2.googleapis.com/token",
                "redirect_uris": [settings.google_redirect_uri],
            }
        }
        return Flow.from_client_config(
            client_config,
            scopes=GMAIL_SCOPES,
            redirect_uri=settings.google_redirect_uri,
        )
