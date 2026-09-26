"""Application status transitions with immutable history."""


class StatusService:
    async def update_status(
        self,
        user_id: str,
        application_id: str,
        new_status: str,
        note: str | None = None,
    ) -> dict:
        """Update current status and append application_status_history."""
        raise NotImplementedError
