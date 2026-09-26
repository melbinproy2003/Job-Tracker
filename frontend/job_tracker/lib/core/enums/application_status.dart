enum ApplicationStatus {
  saved('SAVED', 'Saved'),
  applied('APPLIED', 'Applied'),
  viewed('VIEWED', 'Viewed'),
  shortlisted('SHORTLISTED', 'Shortlisted'),
  hrCall('HR_CALL', 'HR Call'),
  technicalRound('TECHNICAL_ROUND', 'Technical Round'),
  interview('INTERVIEW', 'Interview'),
  finalRound('FINAL_ROUND', 'Final Round'),
  offer('OFFER', 'Offer'),
  accepted('ACCEPTED', 'Accepted'),
  rejected('REJECTED', 'Rejected'),
  withdrawn('WITHDRAWN', 'Withdrawn'),
  noResponse('NO_RESPONSE', 'No Response');

  const ApplicationStatus(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static ApplicationStatus fromApi(String value) {
    return ApplicationStatus.values.firstWhere(
      (e) => e.apiValue == value,
      orElse: () => ApplicationStatus.applied,
    );
  }
}
