"""Symmetric encryption for Gmail tokens at rest (Fernet)."""

from __future__ import annotations

import base64
import hashlib
import logging

from cryptography.fernet import Fernet, InvalidToken

from app.core.config import get_settings
from app.core.exceptions import AppError

logger = logging.getLogger(__name__)


class EncryptionError(AppError):
    def __init__(self, message: str = "Encryption error."):
        super().__init__(message, code="ENCRYPTION_ERROR", status_code=500)


def _fernet() -> Fernet:
    settings = get_settings()
    key = (settings.gmail_token_encryption_key or settings.encryption_key or "").strip()
    if not key:
        raise EncryptionError("GMAIL_TOKEN_ENCRYPTION_KEY / ENCRYPTION_KEY is not configured.")
    # Accept raw Fernet key or derive from any secret string
    try:
        if len(key) == 44 and key.endswith("="):
            return Fernet(key.encode("utf-8"))
    except Exception:
        pass
    digest = hashlib.sha256(key.encode("utf-8")).digest()
    return Fernet(base64.urlsafe_b64encode(digest))


def encrypt_secret(plaintext: str) -> str:
    if plaintext is None:
        raise EncryptionError("Cannot encrypt empty secret.")
    return _fernet().encrypt(plaintext.encode("utf-8")).decode("utf-8")


def decrypt_secret(ciphertext: str) -> str:
    if not ciphertext:
        raise EncryptionError("Cannot decrypt empty ciphertext.")
    try:
        return _fernet().decrypt(ciphertext.encode("utf-8")).decode("utf-8")
    except InvalidToken as exc:
        raise EncryptionError("Invalid encrypted secret.") from exc
