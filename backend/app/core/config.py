"""Application configuration loaded from environment variables."""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Central settings for the FastAPI application."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_name: str = "Job Application Tracker"
    app_env: str = "development"
    api_version: str = "v1"

    api_env: str = "development"
    environment: str = ""
    api_base_url: str = "http://localhost:8000"
    backend_url: str = ""
    api_host: str = "0.0.0.0"
    api_port: int = 8000
    cors_origins: str = "http://localhost:3000,http://127.0.0.1:3000"

    firebase_project_id: str = ""
    firebase_client_email: str = ""
    firebase_private_key: str = ""

    google_client_id: str = ""
    google_client_secret: str = ""
    google_redirect_uri: str = "http://localhost:8000/api/v1/gmail/callback"
    oauth_redirect_uri: str = ""
    encryption_key: str = ""
    gmail_token_encryption_key: str = ""
    gmail_frontend_success_url: str = "jobtracker://gmail/connected"
    gmail_frontend_error_url: str = "jobtracker://gmail/error"

    # Minimum seconds between two manual/scheduled Gmail syncs for one user.
    # Each sync costs Gmail API quota against the user's own 403, so the
    # endpoint is rate limited rather than left open to a looping client.
    # Set to 0 to disable (e.g. in tests).
    gmail_sync_cooldown_seconds: int = 60
    gmail_full_sync_cooldown_seconds: int = 300

    log_level: str = "INFO"

    def model_post_init(self, __context: object) -> None:
        """Strip whitespace/newlines from string settings and resolve redirect URI."""
        import os

        self.app_env = self.app_env.strip()
        self.api_env = self.api_env.strip()
        self.environment = self.environment.strip()
        self.api_base_url = self.api_base_url.strip().rstrip("/")
        self.backend_url = self.backend_url.strip().rstrip("/")
        self.google_client_id = self.google_client_id.strip()
        self.google_client_secret = self.google_client_secret.strip()
        self.google_redirect_uri = self.google_redirect_uri.strip()
        self.oauth_redirect_uri = self.oauth_redirect_uri.strip()
        self.gmail_frontend_success_url = self.gmail_frontend_success_url.strip()
        self.gmail_frontend_error_url = self.gmail_frontend_error_url.strip()

        # If GOOGLE_REDIRECT_URI was not explicitly overridden (or is empty)
        # and OAUTH_REDIRECT_URI is provided, use OAUTH_REDIRECT_URI.
        default_local_cb = "http://localhost:8000/api/v1/gmail/callback"
        is_default_cb = not self.google_redirect_uri or self.google_redirect_uri == default_local_cb
        if is_default_cb and self.oauth_redirect_uri:
            self.google_redirect_uri = self.oauth_redirect_uri

        # If running in production / Vercel and google_redirect_uri is still empty
        # or pointing to the local default, derive the production callback URL.
        is_vercel = bool(os.environ.get("VERCEL") or os.environ.get("VERCEL_ENV") == "production")
        if (not self.is_development or is_vercel) and (
            not self.google_redirect_uri or self.google_redirect_uri == default_local_cb
        ):
            base = self.backend_url or self.api_base_url
            if base and not any(h in base for h in ("localhost", "127.0.0.1", "0.0.0.0")):
                self.google_redirect_uri = f"{base.rstrip('/')}/api/v1/gmail/callback"
            else:
                vercel_prod_host = os.environ.get("VERCEL_PROJECT_PRODUCTION_URL", "").strip()
                if vercel_prod_host:
                    host = (
                        vercel_prod_host.removeprefix("https://")
                        .removeprefix("http://")
                        .rstrip("/")
                    )
                    self.google_redirect_uri = f"https://{host}/api/v1/gmail/callback"
                elif is_vercel or not self.is_development:
                    self.google_redirect_uri = (
                        "https://job-tracker-one-jade.vercel.app/api/v1/gmail/callback"
                    )

    @property
    def is_development(self) -> bool:
        import os

        if os.environ.get("VERCEL_ENV", "").strip().lower() == "production":
            return False
        envs = {
            self.app_env.lower(),
            self.api_env.lower(),
            self.environment.lower(),
        } - {""}
        if any(e in {"production", "prod", "staging"} for e in envs):
            return False
        return all(e in {"development", "dev", "local", "test", "testing"} for e in envs)

    @property
    def resolved_google_redirect_uri(self) -> str:
        """Return the normalized Google OAuth callback URL."""
        return self.google_redirect_uri.strip()

    def validate_google_redirect_uri(self) -> str:
        """Validate that the Google OAuth redirect URI is safe and well-formed."""
        from urllib.parse import urlparse

        from app.core.exceptions import ValidationError

        uri = self.resolved_google_redirect_uri
        if not uri:
            raise ValidationError(
                "GOOGLE_REDIRECT_URI is not configured.",
                code="INVALID_OAUTH_REDIRECT_URI",
            )
        parsed = urlparse(uri)
        if parsed.scheme not in {"http", "https"} or not parsed.netloc:
            raise ValidationError(
                "GOOGLE_REDIRECT_URI must be an HTTP(S) backend callback URL, not a deep link.",
                code="INVALID_OAUTH_REDIRECT_URI",
            )
        if not parsed.path.endswith("/api/v1/gmail/callback"):
            raise ValidationError(
                "GOOGLE_REDIRECT_URI must end with /api/v1/gmail/callback.",
                code="INVALID_OAUTH_REDIRECT_URI",
            )
        host = (parsed.hostname or "").lower()
        if not self.is_development:
            if parsed.scheme != "https":
                raise ValidationError(
                    "Production GOOGLE_REDIRECT_URI must use HTTPS.",
                    code="INVALID_OAUTH_REDIRECT_URI",
                )
            if host in {"localhost", "127.0.0.1", "0.0.0.0"} or host.endswith(
                (".ngrok.io", ".ngrok-free.app")
            ):
                raise ValidationError(
                    "Production GOOGLE_REDIRECT_URI cannot use localhost or a development tunnel.",
                    code="INVALID_OAUTH_REDIRECT_URI",
                )
        return uri

    def firebase_private_key_normalized(self) -> str:
        """Normalize escaped newlines from .env private keys."""
        return self.firebase_private_key.replace("\\n", "\n").strip()


@lru_cache
def get_settings() -> Settings:
    """Return cached settings instance."""
    return Settings()
