"""Text sanitization and normalization utilities."""


def sanitize_text(value: str | None, *, max_length: int = 10_000) -> str | None:
    if value is None:
        return None
    cleaned = value.strip()
    if len(cleaned) > max_length:
        return cleaned[:max_length]
    return cleaned


def normalize_email_address(value: str | None) -> str | None:
    if not value:
        return None
    return value.strip().lower()


def normalize_company_name(name: str) -> str:
    """Case-insensitive, whitespace-collapsed name for duplicate detection."""
    return " ".join(name.strip().lower().split())
