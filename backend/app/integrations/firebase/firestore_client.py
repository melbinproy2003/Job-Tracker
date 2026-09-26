"""Firestore client helpers."""

from __future__ import annotations

from firebase_admin import firestore
from google.cloud.firestore import Client

from app.core.firebase import get_firebase_app


def get_firestore_client() -> Client:
    """Return a Firestore client bound to the initialized Admin app."""
    get_firebase_app()
    return firestore.client()
