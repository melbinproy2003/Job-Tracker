"""Email normalization helpers."""

from __future__ import annotations

import re


_PREFIX_RE = re.compile(r"^(re|fwd|fw)\s*:\s*", re.IGNORECASE)


def normalize_email(address: str | None) -> str:
    if not address:
        return ""
    value = address.strip().lower()
    # Extract email from "Name <email@x.com>"
    match = re.search(r"<([^>]+)>", value)
    if match:
        value = match.group(1).strip().lower()
    return value


def normalize_subject(subject: str | None) -> str:
    if not subject:
        return ""
    value = subject.strip()
    while True:
        updated = _PREFIX_RE.sub("", value).strip()
        if updated == value:
            break
        value = updated
    return value


def extract_domain(address: str | None) -> str:
    email = normalize_email(address)
    if "@" not in email:
        return ""
    return email.split("@", 1)[1]


def company_name_from_domain(domain: str) -> str:
    if not domain:
        return ""
    base = domain.split(".")[0]
    return base.replace("-", " ").replace("_", " ").title()
