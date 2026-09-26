"""Google OAuth configuration helpers for Gmail integration."""

from app.core.config import get_settings


def get_oauth_client_config() -> dict[str, str]:
    """Return Google OAuth client config for server-side use only."""
    settings = get_settings()
    return {
        "client_id": settings.google_client_id,
        "client_secret": settings.google_client_secret,
        "redirect_uri": settings.google_redirect_uri,
    }


def build_authorization_url(state: str) -> str:
    """Build Google OAuth authorization URL.

    Placeholder: Phase 5 will construct the full OAuth URL with Gmail scopes.
    """
    raise NotImplementedError("Gmail OAuth authorization URL not implemented yet")
