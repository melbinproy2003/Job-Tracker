enum InterviewType {
  phoneScreen('PHONE_SCREEN', 'Phone Screen'),
  hrInterview('HR_INTERVIEW', 'HR Interview'),
  technicalInterview('TECHNICAL_INTERVIEW', 'Technical Interview'),
  codingTest('CODING_TEST', 'Coding Test'),
  systemDesign('SYSTEM_DESIGN', 'System Design'),
  managerInterview('MANAGER_INTERVIEW', 'Manager Interview'),
  finalInterview('FINAL_INTERVIEW', 'Final Interview'),
  other('OTHER', 'Other');

  const InterviewType(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static InterviewType fromApi(String value) {
    return InterviewType.values.firstWhere(
      (e) => e.apiValue == value,
      orElse: () => InterviewType.other,
    );
  }
}

enum InterviewStatus {
  scheduled('SCHEDULED', 'Scheduled'),
  completed('COMPLETED', 'Completed'),
  cancelled('CANCELLED', 'Cancelled'),
  rescheduled('RESCHEDULED', 'Rescheduled'),
  noShow('NO_SHOW', 'No Show');

  const InterviewStatus(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static InterviewStatus fromApi(String value) {
    return InterviewStatus.values.firstWhere(
      (e) => e.apiValue == value,
      orElse: () => InterviewStatus.scheduled,
    );
  }
}
