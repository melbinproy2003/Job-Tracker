enum ActivityType {
  applicationCreated('APPLICATION_CREATED', 'Application created'),
  statusChanged('STATUS_CHANGED', 'Status changed'),
  interviewCreated('INTERVIEW_CREATED', 'Interview created'),
  interviewCompleted('INTERVIEW_COMPLETED', 'Interview completed'),
  followupCreated('FOLLOWUP_CREATED', 'Follow-up created'),
  followupCompleted('FOLLOWUP_COMPLETED', 'Follow-up completed'),
  applicationUpdated('APPLICATION_UPDATED', 'Application updated'),
  gmailEmailReceived('GMAIL_EMAIL_RECEIVED', 'Email received'),
  gmailEmailMatched('GMAIL_EMAIL_MATCHED', 'Email matched'),
  gmailStatusSuggestion('GMAIL_STATUS_SUGGESTION', 'Status suggestion'),
  interviewSuggestion('INTERVIEW_SUGGESTION', 'Interview suggestion');

  const ActivityType(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static ActivityType fromApi(String value) {
    return ActivityType.values.firstWhere(
      (e) => e.apiValue == value,
      orElse: () => ActivityType.applicationUpdated,
    );
  }
}
