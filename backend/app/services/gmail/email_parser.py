"""Parse and normalize Gmail API message payloads."""

from __future__ import annotations

import base64
import re
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
from typing import Any

from app.utils.email import normalize_email, normalize_subject


def _header_map(payload: dict[str, Any]) -> dict[str, str]:
    headers = payload.get("headers") or []
    return {h.get("name", "").lower(): h.get("value", "") for h in headers if isinstance(h, dict)}


def _decode_body(data: str | None) -> str:
    if not data:
        return ""
    try:
        padded = data + "=" * (-len(data) % 4)
        return base64.urlsafe_b64decode(padded.encode("utf-8")).decode("utf-8", errors="replace")
    except Exception:
        return ""


def extract_text_body(payload: dict[str, Any] | None) -> str:
    if not payload:
        return ""
    mime = payload.get("mimeType") or ""
    body = payload.get("body") or {}
    if mime == "text/plain" and body.get("data"):
        return _decode_body(body.get("data"))
    parts = payload.get("parts") or []
    texts = []
    for part in parts:
        texts.append(extract_text_body(part))
    return "\n".join(t for t in texts if t).strip()


def parse_gmail_message(raw: dict[str, Any]) -> dict[str, Any]:
    payload = raw.get("payload") or {}
    headers = _header_map(payload)
    subject = normalize_subject(headers.get("subject"))
    from_address = normalize_email(headers.get("from"))
    to_address = normalize_email(headers.get("to"))
    date_raw = headers.get("date")
    received_at = None
    if date_raw:
        try:
            received_at = parsedate_to_datetime(date_raw)
            if received_at.tzinfo is None:
                received_at = received_at.replace(tzinfo=timezone.utc)
        except Exception:
            received_at = None
    if received_at is None and raw.get("internalDate"):
        try:
            received_at = datetime.fromtimestamp(int(raw["internalDate"]) / 1000, tz=timezone.utc)
        except Exception:
            received_at = None

    body_text = extract_text_body(payload)
    # Cap body size
    if len(body_text) > 4000:
        body_text = body_text[:4000]

    return {
        "gmail_message_id": raw.get("id"),
        "gmail_thread_id": raw.get("threadId"),
        "subject": subject,
        "from_address": from_address,
        "to_address": to_address,
        "snippet": (raw.get("snippet") or "")[:500],
        "body_text": body_text,
        "received_at": received_at,
        "normalized_subject": subject,
    }
