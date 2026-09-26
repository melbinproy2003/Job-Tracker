"""Match Gmail messages/threads to user applications."""

from __future__ import annotations

from typing import Any

from app.utils.email import company_name_from_domain, extract_domain, normalize_email


def confidence_label(score: int) -> str:
    if score >= 90:
        return "Very High"
    if score >= 70:
        return "High"
    if score >= 40:
        return "Medium"
    return "Low"


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

        for app in applications:
            score = 0
            reasons: list[str] = []
            if existing_thread_application_id and existing_thread_application_id == app.get("id"):
                score += 100
                reasons.append("thread_match")

            company_name = (app.get("company_name") or "").lower()
            job_title = (app.get("job_title") or "").lower()
            recruiter = normalize_email(app.get("recruiter_email"))

            if recruiter and recruiter == sender:
                score += 20
                reasons.append("recruiter_match")

            if company_name and company_name in hay:
                score += 25
                reasons.append("company_name_match")

            # Domain heuristic: careers@abc.com vs company name abc
            if sender_domain:
                domain_base = company_name_from_domain(sender_domain).lower()
                if domain_base and domain_base in company_name:
                    score += 40
                    reasons.append("company_domain_match")
                elif company_name and company_name.split()[0] in sender_domain:
                    score += 40
                    reasons.append("company_domain_match")

            if job_title:
                # loose token overlap
                tokens = [t for t in job_title.replace("/", " ").split() if len(t) > 2]
                hits = sum(1 for t in tokens if t in hay)
                if hits >= max(1, len(tokens) // 2):
                    score += 25
                    reasons.append("job_title_match")

            score = min(score, 100)
            if score > 0:
                results.append(
                    {
                        "application_id": app["id"],
                        "company_name": app.get("company_name"),
                        "job_title": app.get("job_title"),
                        "confidence": score,
                        "confidence_label": confidence_label(score),
                        "reasons": reasons,
                    }
                )

        results.sort(key=lambda x: x["confidence"], reverse=True)
        return results

    def best_match(self, candidates: list[dict[str, Any]]) -> dict[str, Any] | None:
        if not candidates:
            return None
        return candidates[0]
