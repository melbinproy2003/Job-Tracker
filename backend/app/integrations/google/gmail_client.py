"""Low-level Gmail API client."""

from __future__ import annotations

import base64
from email.utils import parsedate_to_datetime
from typing import Any

from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build

from app.core.config import get_settings
from app.integrations.google.oauth_client import GMAIL_SCOPES


class GoogleGmailClient:
    def __init__(self, access_token: str, refresh_token: str | None = None):
        settings = get_settings()
        self._creds = Credentials(
            token=access_token,
            refresh_token=refresh_token,
            token_uri="https://oauth2.googleapis.com/token",
            client_id=settings.google_client_id,
            client_secret=settings.google_client_secret,
            scopes=GMAIL_SCOPES,
        )
        self._service = build("gmail", "v1", credentials=self._creds, cache_discovery=False)

    def get_profile_email(self) -> str:
        profile = self._service.users().getProfile(userId="me").execute()
        return (profile.get("emailAddress") or "").lower()

    def list_message_ids(
        self,
        *,
        query: str = "",
        max_results: int = 50,
        page_token: str | None = None,
    ) -> dict[str, Any]:
        kwargs: dict[str, Any] = {
            "userId": "me",
            "maxResults": max_results,
            "q": query,
        }
        if page_token:
            kwargs["pageToken"] = page_token
        return self._service.users().messages().list(**kwargs).execute()

    def get_message(self, message_id: str) -> dict[str, Any]:
        return (
            self._service.users()
            .messages()
            .get(userId="me", id=message_id, format="full")
            .execute()
        )

    def get_history(self, start_history_id: str, max_results: int = 100) -> dict[str, Any]:
        return (
            self._service.users()
            .history()
            .list(userId="me", startHistoryId=start_history_id, maxResults=max_results)
            .execute()
        )

    def get_profile_history_id(self) -> str | None:
        profile = self._service.users().getProfile(userId="me").execute()
        hid = profile.get("historyId")
        return str(hid) if hid is not None else None
