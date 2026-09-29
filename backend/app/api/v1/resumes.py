"""Resume endpoints."""

from fastapi import APIRouter, Depends, HTTPException, status

from app.api.v1.dependencies import get_current_user_id

router = APIRouter()


@router.get("")
async def list_resumes(user_id: str = Depends(get_current_user_id)) -> dict:
    raise HTTPException(status_code=status.HTTP_501_NOT_IMPLEMENTED, detail="Not implemented")
