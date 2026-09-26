import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/dashboard_summary.dart';

class DashboardModel {
  DashboardModel.fromJson(Map<String, dynamic> json)
    : totalApplications = json['total_applications'] as int? ?? 0,
      activeApplications = json['active_applications'] as int? ?? 0,
      interviews = json['interviews'] as int? ?? 0,
      upcomingInterviews = json['upcoming_interviews'] as int? ?? 0,
      completedInterviews = json['completed_interviews'] as int? ?? 0,
      pendingFollowups = json['pending_followups'] as int? ?? 0,
      overdueFollowups = json['overdue_followups'] as int? ?? 0,
      completedFollowups = json['completed_followups'] as int? ?? 0,
      offers = json['offers'] as int? ?? 0,
      accepted = json['accepted'] as int? ?? 0,
      rejected = json['rejected'] as int? ?? 0,
      followupsDue = json['followups_due'] as int? ?? 0,
      statusDistribution = _parseDistribution(json['status_distribution']),
      recentApplications = _parseRecent(json['recent_applications']),
      upcomingEvents = _parseEvents(json['upcoming_events']);

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

  DashboardSummary toEntity() => DashboardSummary(
    totalApplications: totalApplications,
    activeApplications: activeApplications,
    interviews: interviews,
    upcomingInterviews: upcomingInterviews,
    completedInterviews: completedInterviews,
    pendingFollowups: pendingFollowups,
    overdueFollowups: overdueFollowups,
    completedFollowups: completedFollowups,
    offers: offers,
    accepted: accepted,
    rejected: rejected,
    followupsDue: followupsDue,
    statusDistribution: statusDistribution,
    recentApplications: recentApplications,
    upcomingEvents: upcomingEvents,
  );

  static Map<String, int> _parseDistribution(dynamic raw) {
    if (raw is! Map) return {};
    return raw.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
  }

  static List<DashboardRecentApplication> _parseRecent(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) {
      final m = e as Map<String, dynamic>;
      return DashboardRecentApplication(
        id: m['id'] as String,
        companyName: m['company_name'] as String? ?? '',
        jobTitle: m['job_title'] as String? ?? '',
        status: m['status'] as String? ?? '',
        updatedAt: parseApiDateTime(m['updated_at']),
      );
    }).toList();
  }

  static List<DashboardUpcomingEvent> _parseEvents(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) {
      final m = e as Map<String, dynamic>;
      return DashboardUpcomingEvent(
        id: m['id'] as String,
        kind: m['kind'] as String? ?? '',
        title: m['title'] as String? ?? '',
        companyName: m['company_name'] as String?,
        jobTitle: m['job_title'] as String?,
        scheduledAt: requireApiDateTime(m['scheduled_at']),
        applicationId: m['application_id'] as String?,
      );
    }).toList();
  }
}
