"""Read application status history."""


class ApplicationHistoryService:
    async def list_history(self, user_id: str, application_id: str) -> list[dict]:
        raise NotImplementedError
