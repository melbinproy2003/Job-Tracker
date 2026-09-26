"""High-level Gmail operations used by GmailService.

Prefer app.integrations.google.gmail_client for low-level API calls.
"""


class GmailApiFacade:
    async def list_messages(self, access_token: str, query: str | None = None) -> list[dict]:
        raise NotImplementedError

    async def get_thread(self, access_token: str, thread_id: str) -> dict:
        raise NotImplementedError
