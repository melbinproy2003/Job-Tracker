"""Google OAuth helpers for Gmail (backend-only).

PKCE: ``google_auth_oauthlib.Flow`` defaults to ``autogenerate_code_verifier=True``.
Authorization and token exchange must use the *same* Flow-bound verifier (or an
explicitly passed one). We generate the verifier once, persist it with OAuth
state, and pass it into both steps so a fresh Flow on callback still matches.
"""

from __future__ import annotations

import hashlib
import logging
import os
import secrets
import string
from base64 import urlsafe_b64encode
from collections.abc import Iterator
from contextlib import contextmanager
from typing import Any

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import Flow

from app.core.config import get_settings

logger = logging.getLogger(__name__)

GMAIL_SCOPES = [
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/userinfo.email",
    "openid",
]

# RFC 7636 unreserved characters for code_verifier.
_PKCE_ALPHABET = string.ascii_letters + string.digits + "-._~"


def generate_code_verifier(length: int = 64) -> str:
    """Cryptographically secure PKCE code_verifier (43-128 chars)."""
    if length < 43 or length > 128:
        raise ValueError("code_verifier length must be 43-128")
    return "".join(secrets.choice(_PKCE_ALPHABET) for _ in range(length))


def code_challenge_s256(verifier: str) -> str:
    """BASE64URL-ENCODE(SHA256(ASCII(code_verifier))) without padding."""
    digest = hashlib.sha256(verifier.encode("ascii")).digest()
    return urlsafe_b64encode(digest).decode("ascii").rstrip("=")


@contextmanager
def _relax_oauthlib_token_scope() -> Iterator[None]:
    """Allow Google to return a superset of requested scopes.

    With ``include_granted_scopes=true``, Google often adds previously granted
    scopes (e.g. ``profile``). oauthlib then raises a ``Warning`` subclass and
    aborts token parsing unless ``OAUTHLIB_RELAX_TOKEN_SCOPE`` is set.
    """
    key = "OAUTHLIB_RELAX_TOKEN_SCOPE"
    previous = os.environ.get(key)
    os.environ[key] = "1"
    try:
        yield
    finally:
        if previous is None:
            os.environ.pop(key, None)
        else:
            os.environ[key] = previous


class GoogleOAuthClient:
    def build_authorization_url(self, state: str, *, code_verifier: str) -> str:
        """Build Google consent URL including PKCE ``code_challenge`` (S256)."""
        if not code_verifier:
            raise ValueError("code_verifier is required for PKCE authorization")
        flow = self._flow(code_verifier=code_verifier)
        auth_url, _ = flow.authorization_url(
            access_type="offline",
            include_granted_scopes="true",
            prompt="consent",
            state=state,
        )
        return auth_url

    def exchange_code(self, code: str, *, code_verifier: str) -> dict[str, Any]:
        """Exchange authorization code; requires the matching PKCE verifier."""
        if not code_verifier:
            raise ValueError("code_verifier is required for PKCE token exchange")
        flow = self._flow(code_verifier=code_verifier)
        with _relax_oauthlib_token_scope():
            flow.fetch_token(code=code)
        creds = flow.credentials
        scopes = list(creds.scopes or GMAIL_SCOPES)
        logger.info(
            "Gmail token exchange succeeded (scopes=%s, has_refresh=%s)",
            len(scopes),
            bool(creds.refresh_token),
        )
        return {
            "access_token": creds.token,
            "refresh_token": creds.refresh_token,
            "token_expires_at": creds.expiry,
            "scopes": scopes,
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

    def _flow(self, *, code_verifier: str) -> Flow:
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
            code_verifier=code_verifier,
            # Verifier is supplied explicitly; never auto-generate on a fresh Flow.
            autogenerate_code_verifier=False,
        )
