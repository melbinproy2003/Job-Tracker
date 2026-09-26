"""Detect job-related emails and suggest categories/status."""

from __future__ import annotations

import re
from typing import Any

from app.models.enums.application_status import ApplicationStatus


CATEGORY_PATTERNS: list[tuple[str, ApplicationStatus | None, list[str]]] = [
    (
        "OFFER",
        ApplicationStatus.OFFER,
        [r"offer letter", r"job offer", r"employment offer", r"pleased to offer"],
    ),
    (
        "REJECTION",
        ApplicationStatus.REJECTED,
        [
            r"unfortunately",
            r"moved forward with other candidates",
            r"not move forward",
            r"will not be proceeding",
            r"decided to pursue other",
        ],
    ),
    (
        "INTERVIEW",
        ApplicationStatus.INTERVIEW,
        [
            r"interview invitation",
            r"interview scheduled",
            r"schedule an interview",
            r"technical interview",
            r"interview with",
        ],
    ),
    (
        "SHORTLIST",
        ApplicationStatus.SHORTLISTED,
        [
            r"shortlisted",
            r"move forward",
            r"next round",
            r"selected for the next",
        ],
    ),
    (
        "APPLICATION_RECEIVED",
        ApplicationStatus.APPLIED,
        [
            r"application received",
            r"thank you for applying",
            r"application has been received",
            r"application submitted",
            r"we received your application",
        ],
    ),
]

JOB_HINTS = [
    r"careers@",
    r"noreply@.*careers",
    r"recruit",
    r"hiring",
    r"application",
    r"interview",
    r"candidate",
    r"job",
    r"offer",
]


class JobEmailDetector:
    def detect(self, message: dict[str, Any]) -> dict[str, Any]:
        subject = (message.get("subject") or "").lower()
        snippet = (message.get("snippet") or "").lower()
        body = (message.get("body_text") or "").lower()
        sender = (message.get("from_address") or "").lower()
        haystack = f"{subject}\n{snippet}\n{body}\n{sender}"

        category = None
        suggested_status = None
        for cat, status, patterns in CATEGORY_PATTERNS:
            for pat in patterns:
                if re.search(pat, haystack, re.IGNORECASE):
                    category = cat
                    suggested_status = status
                    break
            if category:
                break

        is_job = category is not None
        if not is_job:
            is_job = any(re.search(p, haystack, re.IGNORECASE) for p in JOB_HINTS)

        interview = None
        if category == "INTERVIEW":
            interview = self._extract_interview_hints(haystack, message)

        return {
            "is_job_related": is_job,
            "category": category,
            "suggested_status": suggested_status.value if suggested_status else None,
            "interview_suggestion": interview,
        }

    def _extract_interview_hints(self, text: str, message: dict[str, Any]) -> dict[str, Any]:
        url_match = re.search(r"https?://\S+", message.get("body_text") or message.get("snippet") or "")
        # Simple date/time patterns
        date_match = re.search(
            r"(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+\d{1,2}(,\s*\d{4})?",
            text,
            re.IGNORECASE,
        )
        time_match = re.search(r"\b(\d{1,2}:\d{2}\s*(am|pm)?)\b", text, re.IGNORECASE)
        return {
            "title": message.get("subject") or "Interview",
            "meeting_url": url_match.group(0).rstrip(").,") if url_match else None,
            "date_hint": date_match.group(0) if date_match else None,
            "time_hint": time_match.group(0) if time_match else None,
            "from_address": message.get("from_address"),
        }
