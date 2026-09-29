"""Bounded Gmail body retention / cleanup.

Policy (Phase 6):
- On ingest, body_text is capped at 4000 chars and snippet at 500.
- Cleanup clears ``body_text`` on messages older than ``retain_days`` while
  keeping metadata (subject, sender, snippet, links to applications).
- Never deletes applications, interviews, or status history.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from app.repositories.gmail_message_repository import GmailMessageRepository

DEFAULT_RETAIN_DAYS = 90


class GmailRetentionService:
    def __init__(self, message_repository: GmailMessageRepository | None = None):
        self._messages = message_repository or GmailMessageRepository()

    def clear_old_bodies(self, user_id: str, *, retain_days: int = DEFAULT_RETAIN_DAYS) -> dict:
        cutoff = datetime.now(timezone.utc) - timedelta(days=max(retain_days, 1))
        cleared = 0
        for msg in self._messages.list(user_id):
            received = msg.get("received_at")
            if not isinstance(received, datetime):
                continue
            if received.tzinfo is None:
                received = received.replace(tzinfo=timezone.utc)
            body = msg.get("body_text")
            if body and received < cutoff:
                self._messages.update(user_id, msg["id"], {"body_text": None})
                cleared += 1
        return {
            "messages_cleared": cleared,
            "message": f"Cleared body text on {cleared} messages older than {retain_days} days.",
        }
