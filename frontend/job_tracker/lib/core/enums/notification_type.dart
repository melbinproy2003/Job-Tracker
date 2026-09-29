enum AppNotificationType {
  interviewReminder('INTERVIEW_REMINDER'),
  followupReminder('FOLLOWUP_REMINDER'),
  followupOverdue('FOLLOWUP_OVERDUE'),
  gmailEmailDetected('GMAIL_EMAIL_DETECTED'),
  applicationStatusSuggestion('APPLICATION_STATUS_SUGGESTION'),
  system('SYSTEM');

  const AppNotificationType(this.apiValue);
  final String apiValue;

  static AppNotificationType fromApi(String value) {
    return AppNotificationType.values.firstWhere(
      (e) => e.apiValue == value,
      orElse: () => AppNotificationType.system,
    );
  }
}
