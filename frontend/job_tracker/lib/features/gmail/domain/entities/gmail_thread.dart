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

  static MatchConfidence fromBand(String? band) {
    switch ((band ?? '').toUpperCase()) {
      case 'VERY_HIGH':
        return MatchConfidence.veryHigh;
      case 'HIGH':
        return MatchConfidence.high;
      case 'MEDIUM':
        return MatchConfidence.medium;
      case 'LOW':
        return MatchConfidence.low;
      default:
        return MatchConfidence.unknown;
    }
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
///
/// Phase 6 contract: schedule is always [scheduledAt] (ISO), never date/time
/// hint fields alone.
class InterviewSuggestion {
  const InterviewSuggestion({
    this.type,
    this.interviewType,
    this.title,
    this.scheduledAt,
    this.durationMinutes,
    this.meetingUrl,
    this.location,
    this.interviewerName,
    this.interviewerEmail,
    this.confidence,
  });

  final String? type;
  final String? interviewType;
  final String? title;
  final DateTime? scheduledAt;
  final int? durationMinutes;
  final String? meetingUrl;
  final String? location;
  final String? interviewerName;
  final String? interviewerEmail;
  final double? confidence;

  /// Prefer `interview_type`, fall back to legacy `type`.
  String? get resolvedType => interviewType ?? type;

  factory InterviewSuggestion.fromJson(Map<String, dynamic> json) {
    return InterviewSuggestion(
      type: json['type']?.toString(),
      interviewType: json['interview_type']?.toString(),
      title: json['title']?.toString(),
      scheduledAt: _parse(json['scheduled_at']),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      meetingUrl: json['meeting_url']?.toString(),
      location: json['location']?.toString(),
      interviewerName: json['interviewer_name']?.toString(),
      interviewerEmail: json['interviewer_email']?.toString(),
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }

  /// A suggestion is only actionable once it has a time to schedule.
  bool get isActionable => scheduledAt != null;

  static DateTime? _parse(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }
}

/// One ranked application candidate for a Gmail thread.
class MatchCandidate {
  const MatchCandidate({
    required this.applicationId,
    this.companyName,
    this.jobTitle,
    this.score,
    this.confidence = 0,
    this.confidenceLabel,
    this.confidenceBand,
    this.reasons = const [],
  });

  final String applicationId;
  final String? companyName;
  final String? jobTitle;
  final double? score;
  final int confidence;
  final String? confidenceLabel;
  final String? confidenceBand;
  final List<String> reasons;

  MatchConfidence get band =>
      MatchConfidence.fromBand(confidenceBand) != MatchConfidence.unknown
      ? MatchConfidence.fromBand(confidenceBand)
      : MatchConfidence.fromScore(confidence);

  factory MatchCandidate.fromJson(Map<String, dynamic> json) {
    return MatchCandidate(
      applicationId: json['application_id']?.toString() ?? '',
      companyName: json['company_name']?.toString(),
      jobTitle: json['job_title']?.toString(),
      score: (json['score'] as num?)?.toDouble(),
      confidence: (json['confidence'] as num?)?.toInt() ?? 0,
      confidenceLabel: json['confidence_label']?.toString(),
      confidenceBand: json['confidence_band']?.toString(),
      reasons:
          (json['reasons'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }
}

/// Suggested fields when no application match exists (user must confirm create).
class ApplicationDraftFromEmail {
  const ApplicationDraftFromEmail({
    this.companyName,
    this.companyDomain,
    this.jobTitle,
    this.jobUrl,
    this.location,
    this.recruiterName,
    this.recruiterEmail,
    this.source = 'Gmail',
    this.notes,
    this.fromAddress,
    this.subject,
  });

  final String? companyName;
  final String? companyDomain;
  final String? jobTitle;
  final String? jobUrl;
  final String? location;
  final String? recruiterName;
  final String? recruiterEmail;
  final String source;
  final String? notes;
  final String? fromAddress;
  final String? subject;

  factory ApplicationDraftFromEmail.fromJson(Map<String, dynamic> json) {
    return ApplicationDraftFromEmail(
      companyName: json['company_name']?.toString(),
      companyDomain: json['company_domain']?.toString(),
      jobTitle: json['job_title']?.toString(),
      jobUrl: json['job_url']?.toString(),
      location: json['location']?.toString(),
      recruiterName: json['recruiter_name']?.toString(),
      recruiterEmail: json['recruiter_email']?.toString(),
      source: json['source']?.toString() ?? 'Gmail',
      notes: json['notes']?.toString(),
      fromAddress: json['from_address']?.toString(),
      subject: json['subject']?.toString(),
    );
  }
}

/// Email event on an application timeline.
class GmailTimelineEvent {
  const GmailTimelineEvent({
    required this.id,
    required this.kind,
    required this.title,
    this.occurredAt,
    this.category,
    this.threadId,
    this.messageId,
  });

  final String id;
  final String kind;
  final String title;
  final DateTime? occurredAt;
  final String? category;
  final String? threadId;
  final String? messageId;

  factory GmailTimelineEvent.fromJson(Map<String, dynamic> json) {
    DateTime? occurred;
    final raw = json['occurred_at'];
    if (raw != null) {
      occurred = DateTime.tryParse(raw.toString())?.toLocal();
    }
    return GmailTimelineEvent(
      id: json['id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'email',
      title: json['title']?.toString() ?? '',
      occurredAt: occurred,
      category: json['category']?.toString(),
      threadId: json['thread_id']?.toString(),
      messageId: json['message_id']?.toString(),
    );
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
    this.detectedCategory,
    this.detectionConfidence,
    this.matchedSignals = const [],
    this.suggestedStatus,
    this.matchConfidence,
    this.matchConfidenceLabel,
    this.interviewSuggestion,
    this.matchCandidates = const [],
    this.applicationDraft,
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
  final String? detectedCategory;
  final double? detectionConfidence;
  final List<String> matchedSignals;
  final String? suggestedStatus;
  final int? matchConfidence;
  final String? matchConfidenceLabel;
  final InterviewSuggestion? interviewSuggestion;
  final List<MatchCandidate> matchCandidates;
  final ApplicationDraftFromEmail? applicationDraft;

  bool get isUnresolved =>
      matchStatus == GmailMatchStatus.suggested ||
      matchStatus == GmailMatchStatus.unmatched;

  bool get hasInterviewSuggestion => interviewSuggestion?.isActionable ?? false;

  /// Low-confidence matches are surfaced for review but never auto-applied.
  bool get isLowConfidence =>
      MatchConfidence.fromScore(matchConfidence) == MatchConfidence.low;

  bool get hasDiscoveryDraft => applicationDraft != null;
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
    this.detectionConfidence,
    this.matchedSignals = const [],
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
  final double? detectionConfidence;
  final List<String> matchedSignals;
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

/// Result of confirming, ignoring, or unlinking a match.
class GmailMatchResult {
  const GmailMatchResult({
    required this.threadId,
    required this.matchStatus,
    this.applicationId,
    this.suggestedStatus,
    this.applied = false,
    this.interviewCreated = false,
    this.alreadyApplied = false,
    this.interviewConflict = false,
    this.conflictMessage,
    this.interviewId,
  });

  final String threadId;
  final GmailMatchStatus matchStatus;
  final String? applicationId;
  final String? suggestedStatus;

  /// True only when the user explicitly confirmed a status change.
  final bool applied;
  final bool interviewCreated;
  final bool alreadyApplied;
  final bool interviewConflict;
  final String? conflictMessage;
  final String? interviewId;
}
