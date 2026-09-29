"""Match Gmail messages/threads to user applications with explainable scores."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any
from urllib.parse import urlparse

from app.utils.email import company_name_from_domain, extract_domain, normalize_email

_REASON_LABELS = {
    "thread_match": "Existing Gmail thread linked",
    "recruiter_match": "Recruiter email matches",
    "company_name_match": "Company name appears in email",
    "company_domain_match": "Sender domain matches company",
    "job_title_match": "Job title matches",
    "job_url_match": "Job URL matches",
    "location_match": "Location matches",
    "application_date_proximity": "Email close to application date",
    "employment_type_match": "Employment type matches",
    "subject_similarity": "Subject similar to job title",
}


def confidence_label(score: int) -> str:
    if score >= 90:
        return "Very High"
    if score >= 70:
        return "High"
    if score >= 40:
        return "Medium"
    return "Low"


def _human_reasons(codes: list[str]) -> list[str]:
    return [_REASON_LABELS.get(c, c) for c in codes]


class ApplicationMatcher:
    def find_candidates(
        self,
        *,
        message: dict[str, Any],
        applications: list[dict[str, Any]],
        existing_thread_application_id: str | None = None,
    ) -> list[dict[str, Any]]:
        results: list[dict[str, Any]] = []
        sender = normalize_email(message.get("from_address"))
        sender_domain = extract_domain(sender)
        subject = (message.get("subject") or "").lower()
        body = (message.get("body_text") or message.get("snippet") or "").lower()
        hay = f"{subject} {body}"
        received = message.get("received_at")

        for app in applications:
            score = 0
            reason_codes: list[str] = []
            if existing_thread_application_id and existing_thread_application_id == app.get("id"):
                score += 100
                reason_codes.append("thread_match")

            company_name = (app.get("company_name") or "").lower()
            job_title = (app.get("job_title") or "").lower()
            recruiter = normalize_email(app.get("recruiter_email"))
            job_url = (app.get("job_url") or "").lower()
            location = (app.get("location") or "").lower()
            employment_type = (app.get("employment_type") or "").lower()

            if recruiter and recruiter == sender:
                score += 20
                reason_codes.append("recruiter_match")

            if company_name and company_name in hay:
                score += 25
                reason_codes.append("company_name_match")

            if sender_domain:
                domain_base = company_name_from_domain(sender_domain).lower()
                if (domain_base and domain_base in company_name) or (
                    company_name and company_name.split()[0] in sender_domain
                ):
                    score += 40
                    reason_codes.append("company_domain_match")

            if job_title:
                tokens = [t for t in job_title.replace("/", " ").split() if len(t) > 2]
                hits = sum(1 for t in tokens if t in hay)
                if hits >= max(1, len(tokens) // 2):
                    score += 25
                    reason_codes.append("job_title_match")
                # Subject similarity (secondary)
                subject_hits = sum(1 for t in tokens if t in subject)
                half = max(1, len(tokens) // 2)
                if subject_hits >= half and "job_title_match" not in reason_codes:
                    score += 10
                    reason_codes.append("subject_similarity")

            if job_url:
                try:
                    host = urlparse(
                        job_url if "://" in job_url else f"https://{job_url}"
                    ).netloc.lower()
                except Exception:
                    host = ""
                if host and (host in hay or host.replace("www.", "") in hay):
                    score += 10
                    reason_codes.append("job_url_match")

            if location and len(location) > 2 and location in hay:
                score += 8
                reason_codes.append("location_match")

            if employment_type and employment_type in hay:
                score += 5
                reason_codes.append("employment_type_match")

            applied_at = app.get("applied_at")
            if isinstance(applied_at, datetime) and isinstance(received, datetime):
                a = applied_at if applied_at.tzinfo else applied_at.replace(tzinfo=timezone.utc)
                r = received if received.tzinfo else received.replace(tzinfo=timezone.utc)
                delta_days = abs((r - a).days)
                if delta_days <= 45:
                    score += 8
                    reason_codes.append("application_date_proximity")

            score = min(score, 100)
            if score > 0:
                results.append(
                    {
                        "application_id": app["id"],
                        "company_name": app.get("company_name"),
                        "job_title": app.get("job_title"),
                        "score": round(score / 100, 2),
                        "confidence": score,
                        "confidence_label": confidence_label(score),
                        "confidence_band": _band(score),
                        "reasons": _human_reasons(reason_codes),
                        "reason_codes": reason_codes,
                    }
                )

        results.sort(key=lambda x: x["confidence"], reverse=True)
        return results

    def best_match(self, candidates: list[dict[str, Any]]) -> dict[str, Any] | None:
        if not candidates:
            return None
        return candidates[0]

    def build_application_draft(self, message: dict[str, Any]) -> dict[str, Any]:
        """Pre-fill fields for Create Application from Email (user must confirm)."""
        sender = normalize_email(message.get("from_address"))
        domain = extract_domain(sender)
        company = company_name_from_domain(domain) if domain else None
        subject = message.get("subject") or ""
        # Heuristic: strip common prefixes then take trailing role-like segment.
        job_title = subject
        # Include en/em dashes as Unicode escapes (RUF001).
        for sep in (" - ", " \u2013 ", " \u2014 ", ": "):
            if sep in subject:
                parts = [p.strip() for p in subject.split(sep) if p.strip()]
                if len(parts) >= 2:
                    job_title = parts[-1]
                break

        url_match = None
        body = message.get("body_text") or message.get("snippet") or ""
        import re

        m = re.search(r"https?://[^\s<>\"']+", body)
        if m:
            url_match = m.group(0).rstrip(").,;]")

        return {
            "company_name": company.title() if company else None,
            "company_domain": domain,
            "job_title": job_title or None,
            "job_url": url_match,
            "location": None,
            "recruiter_name": None,
            "recruiter_email": sender,
            "source": "Gmail",
            "notes": f"Created from Gmail: {subject}"[:500],
            "applied_at": message.get("received_at"),
            "from_address": sender,
            "subject": subject,
        }


def _band(score: int) -> str:
    if score >= 90:
        return "VERY_HIGH"
    if score >= 70:
        return "HIGH"
    if score >= 40:
        return "MEDIUM"
    return "LOW"
