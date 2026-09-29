"""Application exception hierarchy and error codes."""

from typing import Any


class AppError(Exception):
    """Base application error."""

    def __init__(
        self,
        message: str,
        *,
        code: str = "INTERNAL_ERROR",
        status_code: int = 500,
        details: Any = None,
    ):
        super().__init__(message)
        self.message = message
        self.code = code
        self.status_code = status_code
        self.details = details


class AuthenticationError(AppError):
    def __init__(
        self,
        message: str = "Authentication is required.",
        *,
        code: str = "AUTHENTICATION_REQUIRED",
    ):
        super().__init__(message, code=code, status_code=401)


class InvalidTokenError(AuthenticationError):
    def __init__(self, message: str = "The provided authentication token is invalid."):
        super().__init__(message, code="INVALID_TOKEN")


class TokenExpiredError(AuthenticationError):
    def __init__(self, message: str = "The authentication token has expired."):
        super().__init__(message, code="TOKEN_EXPIRED")


class AuthorizationError(AppError):
    def __init__(
        self,
        message: str = "Not authorized to access this resource.",
        *,
        code: str = "ACCESS_DENIED",
    ):
        super().__init__(message, code=code, status_code=403)


class NotFoundError(AppError):
    def __init__(self, message: str = "Resource not found.", *, code: str = "NOT_FOUND"):
        super().__init__(message, code=code, status_code=404)


class ValidationError(AppError):
    def __init__(
        self,
        message: str = "Validation failed.",
        *,
        code: str = "INVALID_REQUEST",
        details: Any = None,
    ):
        super().__init__(message, code=code, status_code=422, details=details)


class FirebaseError(AppError):
    def __init__(self, message: str = "Firebase service error."):
        super().__init__(message, code="FIREBASE_ERROR", status_code=502)


class ExternalServiceError(AppError):
    def __init__(self, message: str = "External service error."):
        super().__init__(message, code="EXTERNAL_SERVICE_ERROR", status_code=502)


class ApplicationNotFoundError(NotFoundError):
    def __init__(self, message: str = "Application not found."):
        super().__init__(message, code="APPLICATION_NOT_FOUND")


class ApplicationAccessDeniedError(AuthorizationError):
    def __init__(self, message: str = "You do not have access to this application."):
        super().__init__(message, code="APPLICATION_ACCESS_DENIED")


class CompanyNotFoundError(NotFoundError):
    def __init__(self, message: str = "Company not found."):
        super().__init__(message, code="COMPANY_NOT_FOUND")


class CompanyAccessDeniedError(AuthorizationError):
    def __init__(self, message: str = "You do not have access to this company."):
        super().__init__(message, code="COMPANY_ACCESS_DENIED")


class DuplicateCompanyError(ValidationError):
    def __init__(self, message: str = "A company with this name already exists."):
        super().__init__(message, code="DUPLICATE_COMPANY")


class CompanyHasApplicationsError(ValidationError):
    def __init__(self, message: str = "This company has applications and cannot be deleted."):
        super().__init__(message, code="COMPANY_HAS_APPLICATIONS")


class InvalidApplicationStatusError(ValidationError):
    def __init__(self, message: str = "Invalid application status."):
        super().__init__(message, code="INVALID_APPLICATION_STATUS")


class InterviewNotFoundError(NotFoundError):
    def __init__(self, message: str = "Interview not found."):
        super().__init__(message, code="INTERVIEW_NOT_FOUND")


class InterviewAccessDeniedError(AuthorizationError):
    def __init__(self, message: str = "You do not have access to this interview."):
        super().__init__(message, code="INTERVIEW_ACCESS_DENIED")


class FollowUpNotFoundError(NotFoundError):
    def __init__(self, message: str = "Follow-up not found."):
        super().__init__(message, code="FOLLOWUP_NOT_FOUND")


class FollowUpAccessDeniedError(AuthorizationError):
    def __init__(self, message: str = "You do not have access to this follow-up."):
        super().__init__(message, code="FOLLOWUP_ACCESS_DENIED")


class InvalidInterviewError(ValidationError):
    def __init__(self, message: str = "Invalid interview data."):
        super().__init__(message, code="INVALID_INTERVIEW")


class InvalidFollowUpError(ValidationError):
    def __init__(self, message: str = "Invalid follow-up data."):
        super().__init__(message, code="INVALID_FOLLOWUP")


class InterviewConflictError(ValidationError):
    def __init__(self, message: str = "You already have an interview scheduled during this time."):
        super().__init__(message, code="INTERVIEW_CONFLICT")


class FollowUpDuplicateError(ValidationError):
    def __init__(self, message: str = "A similar follow-up already exists."):
        super().__init__(message, code="FOLLOWUP_DUPLICATE")


class EventInPastError(ValidationError):
    def __init__(self, message: str = "Event time cannot be in the past."):
        super().__init__(message, code="EVENT_IN_PAST")
