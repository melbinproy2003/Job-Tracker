"""Application status values. Status history is append-only."""

from enum import StrEnum


class ApplicationStatus(StrEnum):
    SAVED = "SAVED"
    APPLIED = "APPLIED"
    VIEWED = "VIEWED"
    SHORTLISTED = "SHORTLISTED"
    HR_CALL = "HR_CALL"
    TECHNICAL_ROUND = "TECHNICAL_ROUND"
    INTERVIEW = "INTERVIEW"
    FINAL_ROUND = "FINAL_ROUND"
    OFFER = "OFFER"
    ACCEPTED = "ACCEPTED"
    REJECTED = "REJECTED"
    WITHDRAWN = "WITHDRAWN"
    NO_RESPONSE = "NO_RESPONSE"
