"""Detect job-related emails with explainable category + interview extraction.

Phase 6 contract: interview_suggestion always uses ``scheduled_at`` (ISO UTC),
never ``date_hint`` / ``time_hint`` alone as the primary schedule field.
"""

from __future__ import annotations

import calendar
import re
from datetime import datetime, timedelta, timezone
from typing import Any

from app.models.enums.application_status import ApplicationStatus
from app.models.enums.email_category import EmailCategory
from app.models.enums.interview_type import InterviewType

# Ordered highest-priority first.
_CATEGORY_RULES: list[tuple[EmailCategory, ApplicationStatus | None, list[str]]] = [
    (
        EmailCategory.OFFER,
        ApplicationStatus.OFFER,
        [r"offer letter", r"job offer", r"employment offer", r"pleased to offer", r"extend an offer"],
    ),
    (
        EmailCategory.REJECTION,
        ApplicationStatus.REJECTED,
        [
            r"unfortunately",
            r"moved forward with other candidates",
            r"not move forward",
            r"will not be proceeding",
            r"decided to pursue other",
            r"not selected",
            r"unsuccessful",
        ],
    ),
    (
        EmailCategory.WITHDRAWAL,
        ApplicationStatus.WITHDRAWN,
        [r"withdrawn your application", r"application has been withdrawn", r"you withdrew"],
    ),
    (
        EmailCategory.FINAL_INTERVIEW,
        ApplicationStatus.FINAL_ROUND,
        [r"final interview", r"final round", r"last round of interviews"],
    ),
    (
        EmailCategory.SYSTEM_DESIGN,
        ApplicationStatus.TECHNICAL_ROUND,
        [r"system design", r"system-design", r"architecture interview"],
    ),
    (
        EmailCategory.CODING_TEST,
        ApplicationStatus.TECHNICAL_ROUND,
        [r"coding test", r"coding challenge", r"online assessment", r"hackerrank", r"codility", r"leetcode"],
    ),
    (
        EmailCategory.TECHNICAL_INTERVIEW,
        ApplicationStatus.TECHNICAL_ROUND,
        [
            r"technical interview",
            r"tech interview",
            r"technical round",
            r"engineering interview",
        ],
    ),
    (
        EmailCategory.MANAGER_INTERVIEW,
        ApplicationStatus.INTERVIEW,
        [r"hiring manager", r"manager interview", r"meet the manager"],
    ),
    (
        EmailCategory.HR_INTERVIEW,
        ApplicationStatus.HR_CALL,
        [r"hr interview", r"hr round", r"human resources interview", r"recruiter interview"],
    ),
    (
        EmailCategory.HR_CONTACT,
        ApplicationStatus.HR_CALL,
        [r"hr call", r"phone screen", r"recruiter call", r"speak with hr", r"talent acquisition"],
    ),
    (
        EmailCategory.ASSESSMENT,
        ApplicationStatus.TECHNICAL_ROUND,
        [r"take-home", r"take home assignment", r"assessment invitation", r"skills assessment"],
    ),
    (
        EmailCategory.SHORTLISTED,
        ApplicationStatus.SHORTLISTED,
        [r"shortlisted", r"move forward", r"next round", r"selected for the next"],
    ),
    (
        EmailCategory.APPLICATION_ACKNOWLEDGED,
        ApplicationStatus.APPLIED,
        [r"application acknowledged", r"we are reviewing your application", r"under review"],
    ),
    (
        EmailCategory.APPLICATION_RECEIVED,
        ApplicationStatus.APPLIED,
        [
            r"application received",
            r"thank you for applying",
            r"application has been received",
            r"application submitted",
            r"we received your application",
        ],
    ),
    (
        EmailCategory.FOLLOW_UP,
        None,
        [r"following up on your application", r"checking in on your candidacy", r"any update on your application"],
    ),
    # Generic interview invitation (after specific types).
    (
        EmailCategory.TECHNICAL_INTERVIEW,
        ApplicationStatus.TECHNICAL_ROUND,
        [
            r"interview invitation",
            r"interview scheduled",
            r"schedule an interview",
            r"interview with",
            r"invite you to interview",
        ],
    ),
]

_JOB_HINTS = [
    r"careers@",
    r"noreply@.*careers",
    r"recruit",
    r"hiring",
    r"application",
    r"interview",
    r"candidate",
    r"\bjob\b",
    r"offer",
]

_MONTHS = {m.lower(): i for i, m in enumerate(calendar.month_abbr) if m}
_MONTHS.update({m.lower(): i for i, m in enumerate(calendar.month_name) if m})

_INTERVIEW_CATEGORIES = {
    EmailCategory.TECHNICAL_INTERVIEW,
    EmailCategory.HR_INTERVIEW,
    EmailCategory.CODING_TEST,
    EmailCategory.SYSTEM_DESIGN,
    EmailCategory.MANAGER_INTERVIEW,
    EmailCategory.FINAL_INTERVIEW,
    EmailCategory.ASSESSMENT,
}


def _category_to_interview_type(category: EmailCategory) -> InterviewType:
    return {
        EmailCategory.TECHNICAL_INTERVIEW: InterviewType.TECHNICAL_INTERVIEW,
        EmailCategory.HR_INTERVIEW: InterviewType.HR_INTERVIEW,
        EmailCategory.CODING_TEST: InterviewType.CODING_TEST,
        EmailCategory.SYSTEM_DESIGN: InterviewType.SYSTEM_DESIGN,
        EmailCategory.MANAGER_INTERVIEW: InterviewType.MANAGER_INTERVIEW,
        EmailCategory.FINAL_INTERVIEW: InterviewType.FINAL_INTERVIEW,
        EmailCategory.HR_CONTACT: InterviewType.PHONE_SCREEN,
        EmailCategory.ASSESSMENT: InterviewType.CODING_TEST,
    }.get(category, InterviewType.OTHER)


class JobEmailDetector:
    def detect(self, message: dict[str, Any]) -> dict[str, Any]:
        subject = (message.get("subject") or "").lower()
        snippet = (message.get("snippet") or "").lower()
        body = (message.get("body_text") or "").lower()
        sender = (message.get("from_address") or "").lower()
        haystack = f"{subject}\n{snippet}\n{body}\n{sender}"

        category: EmailCategory | None = None
        suggested_status: ApplicationStatus | None = None
        matched_signals: list[str] = []
        confidence = 0.0

        for cat, status, patterns in _CATEGORY_RULES:
            for pat in patterns:
                match = re.search(pat, haystack, re.IGNORECASE)
                if match:
                    category = cat
                    suggested_status = status
                    matched_signals.append(match.group(0).strip())
                    confidence = 0.72
                    break
            if category:
                break

        is_job = category is not None
        if not is_job:
            for p in _JOB_HINTS:
                match = re.search(p, haystack, re.IGNORECASE)
                if match:
                    is_job = True
                    category = EmailCategory.OTHER_JOB_RELATED
                    matched_signals.append(match.group(0).strip())
                    confidence = 0.45
                    break
            if not is_job:
                category = EmailCategory.NOT_JOB_RELATED
                confidence = 0.9

        # Boost confidence with corroborating signals.
        if category and category != EmailCategory.NOT_JOB_RELATED:
            if re.search(r"https?://", haystack):
                matched_signals.append("meeting link")
                confidence = min(1.0, confidence + 0.08)
            if re.search(
                r"(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+\d{1,2}",
                haystack,
                re.IGNORECASE,
            ):
                matched_signals.append("scheduled date")
                confidence = min(1.0, confidence + 0.08)
            if re.search(r"\b\d{1,2}:\d{2}\s*(am|pm)\b", haystack, re.IGNORECASE):
                matched_signals.append("scheduled time")
                confidence = min(1.0, confidence + 0.05)
            if "careers@" in sender or "recruit" in sender:
                matched_signals.append("careers sender")
                confidence = min(1.0, confidence + 0.05)

        # Deduplicate signals while preserving order.
        seen: set[str] = set()
        unique_signals: list[str] = []
        for s in matched_signals:
            key = s.lower()
            if key not in seen:
                seen.add(key)
                unique_signals.append(s)

        interview = None
        if category in _INTERVIEW_CATEGORIES:
            interview = self._extract_interview(message, category, haystack)
            if interview.get("scheduled_at"):
                confidence = min(1.0, max(confidence, 0.85))
            if interview.get("meeting_url") and "meeting link" not in {
                s.lower() for s in unique_signals
            }:
                unique_signals.append("meeting link")

        return {
            "is_job_related": is_job and category != EmailCategory.NOT_JOB_RELATED,
            "category": category.value if category else None,
            "confidence": round(confidence, 2),
            "matched_signals": unique_signals,
            "suggested_status": suggested_status.value if suggested_status else None,
            "interview_suggestion": interview,
        }

    def _extract_interview(
        self, message: dict[str, Any], category: EmailCategory, text: str
    ) -> dict[str, Any]:
        raw_body = message.get("body_text") or message.get("snippet") or ""
        url_match = re.search(r"https?://[^\s<>\"']+", raw_body)
        meeting_url = url_match.group(0).rstrip(").,;]") if url_match else None

        scheduled_at = self._parse_scheduled_at(text, message.get("received_at"))
        interviewer_email = None
        from_addr = message.get("from_address")
        if from_addr and "@" in from_addr:
            interviewer_email = from_addr

        itype = _category_to_interview_type(category)
        conf = 0.92 if scheduled_at else 0.55

        return {
            "title": message.get("subject") or itype.value.replace("_", " ").title(),
            "scheduled_at": scheduled_at.isoformat().replace("+00:00", "Z") if scheduled_at else None,
            "duration_minutes": 60 if scheduled_at else None,
            "meeting_url": meeting_url,
            "location": None,
            "interviewer_name": None,
            "interviewer_email": interviewer_email,
            "interview_type": itype.value,
            # Alias used by older Flutter clients that read `type`.
            "type": itype.value,
            "confidence": conf,
        }

    def _parse_scheduled_at(
        self, text: str, received_at: datetime | None
    ) -> datetime | None:
        """Best-effort local-wall-time parse → UTC. Returns None if ambiguous."""
        date_match = re.search(
            r"\b(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\s+(\d{1,2})"
            r"(?:,?\s*(\d{4}))?",
            text,
            re.IGNORECASE,
        )
        time_match = re.search(
            r"\b(\d{1,2}):(\d{2})\s*(am|pm)?\b", text, re.IGNORECASE
        )
        if not date_match:
            return None

        month_raw = date_match.group(1).lower()[:3]
        if month_raw == "sep":
            month = 9
        else:
            month = _MONTHS.get(month_raw) or _MONTHS.get(date_match.group(1).lower())
        if not month:
            return None
        day = int(date_match.group(2))
        year = int(date_match.group(3)) if date_match.group(3) else None
        ref = received_at or datetime.now(timezone.utc)
        if ref.tzinfo is None:
            ref = ref.replace(tzinfo=timezone.utc)
        if year is None:
            year = ref.year
            # If month/day already passed by > 30 days, assume next year.
            try:
                candidate = datetime(year, month, day, tzinfo=timezone.utc)
            except ValueError:
                return None
            if candidate < ref - timedelta(days=30):
                year += 1

        hour, minute = 10, 0
        if time_match:
            hour = int(time_match.group(1))
            minute = int(time_match.group(2))
            ampm = (time_match.group(3) or "").lower()
            if ampm == "pm" and hour < 12:
                hour += 12
            if ampm == "am" and hour == 12:
                hour = 0

        try:
            # Treat parsed wall time as UTC for storage consistency; Flutter
            # converts to local for display. Explicit TZ offsets in email are rare.
            return datetime(year, month, day, hour, minute, tzinfo=timezone.utc)
        except ValueError:
            return None
