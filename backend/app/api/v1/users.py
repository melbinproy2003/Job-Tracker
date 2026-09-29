"""User profile endpoints."""

from fastapi import APIRouter, Depends, HTTPException, status

from app.api.v1.dependencies import get_current_user_id

router = APIRouter()


@router.get("/me")
async def get_user_profile(user_id: str = Depends(get_current_user_id)) -> dict:
    raise HTTPException(status_code=status.HTTP_501_NOT_IMPLEMENTED, detail="Not implemented")
