"""Gmail thread match status."""

from enum import StrEnum


class GmailMatchStatus(StrEnum):
    UNMATCHED = "UNMATCHED"
    SUGGESTED = "SUGGESTED"
    MATCHED = "MATCHED"
    IGNORED = "IGNORED"
