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
    api_base_url: str = "http://localhost:8000"
    api_host: str = "0.0.0.0"
    api_port: int = 8000
    cors_origins: str = "http://localhost:3000,http://127.0.0.1:3000"

    firebase_project_id: str = ""
    firebase_client_email: str = ""
    firebase_private_key: str = ""

    google_client_id: str = ""
    google_client_secret: str = ""
    google_redirect_uri: str = "http://localhost:8000/api/v1/gmail/callback"
    encryption_key: str = ""
    gmail_token_encryption_key: str = ""
    gmail_frontend_success_url: str = "jobtracker://gmail/connected"
    gmail_frontend_error_url: str = "jobtracker://gmail/error"

    log_level: str = "INFO"

    @property
    def is_development(self) -> bool:
        return self.app_env.lower() in {"development", "dev", "local"} or self.api_env.lower() in {
            "development",
            "dev",
            "local",
        }

    def firebase_private_key_normalized(self) -> str:
        """Normalize escaped newlines from .env private keys."""
        return self.firebase_private_key.replace("\\n", "\n").strip()


@lru_cache
def get_settings() -> Settings:
    """Return cached settings instance."""
    return Settings()
