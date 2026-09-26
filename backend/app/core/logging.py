"""Logging configuration."""

import logging
import sys

from app.core.config import get_settings


def configure_logging() -> None:
    """Configure application-wide logging."""
    settings = get_settings()
    logging.basicConfig(
        level=getattr(logging, settings.log_level.upper(), logging.INFO),
        format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
        stream=sys.stdout,
    )
