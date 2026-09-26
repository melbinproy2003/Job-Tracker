/// A Gmail account linked to the user's tracker.
///
/// Intentionally carries no token material of any kind: the backend holds
/// credentials and only ever returns this sanitized projection.
class GmailAccount {
  const GmailAccount({
    required this.id,
    required this.email,
    this.connected = true,
    this.lastSyncAt,
    this.scopes = const [],
  });

  final String id;
  final String email;
  final bool connected;
  final DateTime? lastSyncAt;
  final List<String> scopes;

  bool get hasSynced => lastSyncAt != null;
}

/// Whether a thread has been linked to an application.
enum GmailMatchStatus {
  unmatched,
  suggested,
  matched,
  ignored;

  static GmailMatchStatus fromApi(String? value) {
    switch (value) {
      case 'SUGGESTED':
        return GmailMatchStatus.suggested;
      case 'MATCHED':
        return GmailMatchStatus.matched;
      case 'IGNORED':
        return GmailMatchStatus.ignored;
      default:
        return GmailMatchStatus.unmatched;
    }
  }
}

/// How much to trust an automatic application match.
enum MatchConfidence {
  low,
  medium,
  high,
  veryHigh,
  unknown;

  static MatchConfidence fromScore(int? score) {
    if (score == null) return MatchConfidence.unknown;
    if (score >= 90) return MatchConfidence.veryHigh;
    if (score >= 70) return MatchConfidence.high;
    if (score >= 40) return MatchConfidence.medium;
    return MatchConfidence.low;
  }

  String get label => switch (this) {
    MatchConfidence.low => 'Low',
    MatchConfidence.medium => 'Medium',
    MatchConfidence.high => 'High',
    MatchConfidence.veryHigh => 'Very high',
    MatchConfidence.unknown => 'Unknown',
  };

  /// Low-confidence suggestions must never be auto-applied, and the UI uses
  /// this to withhold the one-tap "link" affordance.
  bool get isReliable =>
      index >= MatchConfidence.medium.index && this != MatchConfidence.unknown;
}

/// An interview the backend extracted from an email, offered for confirmation.
class InterviewSuggestion {
  const InterviewSuggestion({
    this.type,
    this.title,
    this.scheduledAt,
    this.durationMinutes,
    this.meetingUrl,
    this.interviewerName,
  });

  final String? type;
  final String? title;
  final DateTime? scheduledAt;
  final int? durationMinutes;
  final String? meetingUrl;
  final String? interviewerName;

  factory InterviewSuggestion.fromJson(Map<String, dynamic> json) {
    return InterviewSuggestion(
      type: json['type']?.toString(),
      title: json['title']?.toString(),
      scheduledAt: _parse(json['scheduled_at']),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      meetingUrl: json['meeting_url']?.toString(),
      interviewerName: json['interviewer_name']?.toString(),
    );
  }

  /// A suggestion is only actionable once it has a time to schedule.
  bool get isActionable => scheduledAt != null;

  static DateTime? _parse(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }
}

/// A job-related email thread and whatever the matcher inferred about it.
class GmailThread {
  const GmailThread({
    required this.id,
    required this.gmailThreadId,
    this.subject,
    this.snippet,
    this.participants = const [],
    this.lastMessageAt,
    this.applicationId,
    this.matchStatus = GmailMatchStatus.unmatched,
    this.isJobRelated = false,
    this.suggestedStatus,
    this.matchConfidence,
    this.interviewSuggestion,
  });

  final String id;
  final String gmailThreadId;
  final String? subject;
  final String? snippet;
  final List<String> participants;
  final DateTime? lastMessageAt;
  final String? applicationId;
  final GmailMatchStatus matchStatus;
  final bool isJobRelated;
  final String? suggestedStatus;
  final int? matchConfidence;
  final InterviewSuggestion? interviewSuggestion;

  bool get isUnresolved =>
      matchStatus == GmailMatchStatus.suggested ||
      matchStatus == GmailMatchStatus.unmatched;

  bool get hasInterviewSuggestion => interviewSuggestion?.isActionable ?? false;

  /// Low-confidence matches are surfaced for review but never auto-applied.
  bool get isLowConfidence =>
      MatchConfidence.fromScore(matchConfidence) == MatchConfidence.low;
}

/// A single stored email.
class GmailMessage {
  const GmailMessage({
    required this.id,
    required this.gmailMessageId,
    required this.gmailThreadId,
    this.fromAddress,
    this.toAddress,
    this.subject,
    this.snippet,
    this.receivedAt,
    this.bodyText,
    this.applicationId,
    this.isJobRelated = false,
    this.detectedCategory,
  });

  final String id;
  final String gmailMessageId;
  final String gmailThreadId;
  final String? fromAddress;
  final String? toAddress;
  final String? subject;
  final String? snippet;
  final DateTime? receivedAt;
  final String? bodyText;
  final String? applicationId;
  final bool isJobRelated;
  final String? detectedCategory;
}

/// Summary returned by `POST /gmail/sync`.
class GmailSyncResult {
  const GmailSyncResult({
    this.success = true,
    this.messagesChecked = 0,
    this.jobRelatedFound = 0,
    this.matchesSuggested = 0,
    this.lastSyncAt,
    this.message,
  });

  final bool success;
  final int messagesChecked;
  final int jobRelatedFound;
  final int matchesSuggested;
  final DateTime? lastSyncAt;
  final String? message;
}

/// Result of confirming or ignoring a match.
class GmailMatchResult {
  const GmailMatchResult({
    required this.threadId,
    required this.matchStatus,
    this.applicationId,
    this.suggestedStatus,
    this.applied = false,
    this.interviewCreated = false,
  });

  final String threadId;
  final GmailMatchStatus matchStatus;
  final String? applicationId;
  final String? suggestedStatus;

  /// True only when the user explicitly confirmed a status change.
  final bool applied;
  final bool interviewCreated;
}
