"""Security helpers: Firebase ID token verification."""

from __future__ import annotations

import logging
from typing import Any

from firebase_admin import auth as firebase_auth
from firebase_admin.auth import (
    ExpiredIdTokenError,
    InvalidIdTokenError,
    RevokedIdTokenError,
)
from starlette.concurrency import run_in_threadpool

from app.core.exceptions import (
    FirebaseError,
    InvalidTokenError,
    TokenExpiredError,
)
from app.core.firebase import get_firebase_app, is_firebase_initialized

logger = logging.getLogger(__name__)


class FirebaseTokenVerifier:
    """Verifies Firebase ID tokens via the Admin SDK."""

    def verify(self, id_token: str) -> dict[str, Any]:
        """Verify a Firebase ID token and return decoded claims.

        Never logs the token itself.
        """
        if not id_token or not id_token.strip():
            raise InvalidTokenError("Missing authentication token.")

        if not is_firebase_initialized():
            try:
                get_firebase_app()
            except FirebaseError as exc:
                raise FirebaseError("Authentication service is unavailable.") from exc

        try:
            # check_revoked=False avoids extra round-trips; can enable later.
            claims = firebase_auth.verify_id_token(id_token.strip(), check_revoked=False)
        except ExpiredIdTokenError as exc:
            logger.info("Rejected expired Firebase ID token")
            raise TokenExpiredError() from exc
        except (InvalidIdTokenError, RevokedIdTokenError, ValueError) as exc:
            logger.info("Rejected invalid Firebase ID token")
            raise InvalidTokenError() from exc
        except Exception as exc:
            logger.exception("Firebase token verification failed")
            raise FirebaseError("Unable to verify authentication token.") from exc

        uid = claims.get("uid") or claims.get("sub")
        if not uid:
            raise InvalidTokenError("Authenticated token missing user identity.")

        return claims


_token_verifier = FirebaseTokenVerifier()


async def verify_firebase_id_token(id_token: str) -> dict[str, Any]:
    """Async wrapper around FirebaseTokenVerifier.

    ``verify_id_token`` performs blocking network I/O against the Firebase Auth
    backend, so it is dispatched to a worker thread to keep the event loop free.
    """
    return await run_in_threadpool(_token_verifier.verify, id_token)


def get_user_id_from_claims(claims: dict[str, Any]) -> str:
    """Extract stable user id from verified Firebase claims."""
    uid = claims.get("uid") or claims.get("sub")
    if not uid:
        raise InvalidTokenError("Authenticated token missing user identity.")
    return str(uid)
