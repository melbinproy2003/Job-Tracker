/// Dashboard aggregate matching backend DashboardResponse.
class DashboardSummary {
  const DashboardSummary({
    required this.totalApplications,
    required this.activeApplications,
    required this.interviews,
    required this.upcomingInterviews,
    required this.completedInterviews,
    required this.pendingFollowups,
    required this.overdueFollowups,
    required this.completedFollowups,
    required this.offers,
    required this.accepted,
    required this.rejected,
    required this.followupsDue,
    required this.statusDistribution,
    required this.recentApplications,
    required this.upcomingEvents,
  });

  final int totalApplications;
  final int activeApplications;
  final int interviews;
  final int upcomingInterviews;
  final int completedInterviews;
  final int pendingFollowups;
  final int overdueFollowups;
  final int completedFollowups;
  final int offers;
  final int accepted;
  final int rejected;
  final int followupsDue;
  final Map<String, int> statusDistribution;
  final List<DashboardRecentApplication> recentApplications;
  final List<DashboardUpcomingEvent> upcomingEvents;
}

class DashboardRecentApplication {
  const DashboardRecentApplication({
    required this.id,
    required this.companyName,
    required this.jobTitle,
    required this.status,
    this.updatedAt,
  });

  final String id;
  final String companyName;
  final String jobTitle;
  final String status;
  final DateTime? updatedAt;
}

class DashboardUpcomingEvent {
  const DashboardUpcomingEvent({
    required this.id,
    required this.kind,
    required this.title,
    required this.scheduledAt,
    this.companyName,
    this.jobTitle,
    this.applicationId,
  });

  final String id;

  /// `interview` or `followup`
  final String kind;
  final String title;
  final String? companyName;
  final String? jobTitle;
  final DateTime scheduledAt;
  final String? applicationId;

  bool get isInterview => kind == 'interview';
  bool get isFollowup => kind == 'followup';
}
