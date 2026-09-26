"""Firebase Admin SDK bootstrap."""

from __future__ import annotations

import logging
from typing import Any

import firebase_admin
from firebase_admin import credentials

from app.core.config import get_settings
from app.core.exceptions import FirebaseError

logger = logging.getLogger(__name__)

_initialized = False


def init_firebase() -> None:
    """Initialize Firebase Admin using credentials from settings."""
    global _initialized
    if _initialized or firebase_admin._apps:
        _initialized = True
        return

    settings = get_settings()
    if not settings.firebase_project_id:
        if settings.is_development:
            logger.warning(
                "Firebase not configured (missing FIREBASE_PROJECT_ID). "
                "Token verification will fail until credentials are set."
            )
            return
        raise FirebaseError("Firebase project is not configured.")

    private_key = settings.firebase_private_key_normalized()
    if not settings.firebase_client_email or not private_key:
        raise FirebaseError("Firebase service account credentials are incomplete.")

    try:
        cred = credentials.Certificate(
            {
                "type": "service_account",
                "project_id": settings.firebase_project_id,
                "private_key": private_key,
                "client_email": settings.firebase_client_email,
                "token_uri": "https://oauth2.googleapis.com/token",
            }
        )
        firebase_admin.initialize_app(
            cred,
            {"projectId": settings.firebase_project_id},
        )
        _initialized = True
        logger.info("Firebase Admin initialized for project %s", settings.firebase_project_id)
    except Exception as exc:
        # Never log private key material.
        logger.exception("Failed to initialize Firebase Admin")
        raise FirebaseError("Failed to initialize Firebase Admin.") from exc


def is_firebase_initialized() -> bool:
    return _initialized or bool(firebase_admin._apps)


def get_firebase_app() -> Any:
    if not is_firebase_initialized():
        init_firebase()
    if not is_firebase_initialized():
        raise FirebaseError("Firebase Admin is not initialized.")
    return firebase_admin.get_app()
