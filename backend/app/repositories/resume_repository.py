"""Resume repository — Firestore data access (placeholder)."""


class ResumeRepository:
    """CRUD against Firestore with user_id isolation."""

    async def list_for_user(self, user_id: str) -> list[dict]:
        raise NotImplementedError

    async def get_for_user(self, user_id: str, entity_id: str) -> dict | None:
        raise NotImplementedError

    async def create(self, user_id: str, data: dict) -> dict:
        raise NotImplementedError

    async def update(self, user_id: str, entity_id: str, data: dict) -> dict:
        raise NotImplementedError

    async def delete(self, user_id: str, entity_id: str) -> None:
        raise NotImplementedError
