"""Gmail OAuth, sync, and matching endpoints (backend-only credentials).

Handlers are intentionally declared ``def`` rather than ``async def``: every
service and repository below performs blocking work (Firestore Admin SDK and
the Gmail REST client), and FastAPI runs sync handlers in a worker thread. That
keeps ``POST /sync`` — which can make dozens of sequential Gmail calls — off the
event loop. See ``notifications.py`` for the same pattern.
"""

from typing import Annotated

from fastapi import APIRouter, Depends, Query
from fastapi.responses import RedirectResponse

from app.api.v1.dependencies import get_current_user_id
from app.schemas.gmail import (
    GmailAccountResponse,
    GmailConnectResponse,
    GmailMatchConfirmRequest,
    GmailMatchResponse,
    GmailMessageResponse,
    GmailSyncRequest,
    GmailSyncResponse,
    GmailThreadResponse,
)
from app.services.gmail.gmail_service import GmailService

router = APIRouter()


def get_gmail_service() -> GmailService:
    return GmailService()


@router.get("/accounts", response_model=list[GmailAccountResponse])
def list_accounts(
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[GmailService, Depends(get_gmail_service)],
) -> list[GmailAccountResponse]:
    return service.list_accounts(user_id)


@router.get("/connect", response_model=GmailConnectResponse)
def gmail_connect(
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[GmailService, Depends(get_gmail_service)],
) -> GmailConnectResponse:
    return GmailConnectResponse(authorization_url=service.start_connect(user_id))


@router.get("/callback")
def gmail_callback(
    service: Annotated[GmailService, Depends(get_gmail_service)],
    code: Annotated[str | None, Query()] = None,
    state: Annotated[str | None, Query()] = None,
) -> RedirectResponse:
    url = service.handle_callback(code, state)
    return RedirectResponse(url=url, status_code=302)


@router.post("/sync", response_model=GmailSyncResponse)
def gmail_sync(
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[GmailService, Depends(get_gmail_service)],
    payload: GmailSyncRequest | None = None,
) -> GmailSyncResponse:
    result = service.sync(user_id, full_sync=bool(payload.full_sync) if payload else False)
    return GmailSyncResponse(**result)


@router.get("/threads", response_model=list[GmailThreadResponse])
def list_gmail_threads(
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[GmailService, Depends(get_gmail_service)],
    application_id: Annotated[str | None, Query()] = None,
) -> list[GmailThreadResponse]:
    return service.list_threads(user_id, application_id=application_id)


@router.get("/threads/{thread_id}", response_model=GmailThreadResponse)
def get_gmail_thread(
    thread_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[GmailService, Depends(get_gmail_service)],
) -> GmailThreadResponse:
    return service.get_thread(user_id, thread_id)


@router.get("/messages/{message_id}", response_model=GmailMessageResponse)
def get_gmail_message(
    message_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[GmailService, Depends(get_gmail_service)],
) -> GmailMessageResponse:
    return service.get_message(user_id, message_id)


@router.post("/matches/{thread_id}/confirm", response_model=GmailMatchResponse)
def confirm_match(
    thread_id: str,
    payload: GmailMatchConfirmRequest,
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[GmailService, Depends(get_gmail_service)],
) -> GmailMatchResponse:
    return service.confirm_match(user_id, thread_id, payload)


@router.post("/matches/{thread_id}/ignore", response_model=GmailMatchResponse)
def ignore_match(
    thread_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[GmailService, Depends(get_gmail_service)],
) -> GmailMatchResponse:
    return service.ignore_match(user_id, thread_id)


@router.delete("/accounts/{account_id}", status_code=204)
def disconnect_account(
    account_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    service: Annotated[GmailService, Depends(get_gmail_service)],
) -> None:
    service.disconnect(user_id, account_id)
