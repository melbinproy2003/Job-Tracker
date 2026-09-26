"""Resume management service."""


class ResumeService:
    async def list(self, user_id: str) -> list[dict]:
        raise NotImplementedError
