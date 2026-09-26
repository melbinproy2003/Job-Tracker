"""Optional background Gmail sync entrypoint."""

from __future__ import annotations

import logging

logger = logging.getLogger(__name__)


def run_gmail_sync_once(user_id: str, *, full_sync: bool = False) -> dict:
    from app.services.gmail.gmail_sync_service import GmailSyncService

    return GmailSyncService().sync(user_id, full_sync=full_sync)


if __name__ == "__main__":
    import sys

    logging.basicConfig(level=logging.INFO)
    if len(sys.argv) < 2:
        print("Usage: python -m app.workers.gmail_sync_worker <user_id>")
        raise SystemExit(1)
    print(run_gmail_sync_once(sys.argv[1]))
