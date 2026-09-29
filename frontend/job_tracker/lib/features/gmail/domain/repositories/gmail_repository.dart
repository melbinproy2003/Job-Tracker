import '../entities/gmail_thread.dart';

/// Domain contract for Gmail connection, sync, and match resolution.
///
/// Note there is no method here that can change an application status without
/// an explicit [GmailMatchConfirm] — the confirmation requirement is encoded in
/// the type, not just in the UI.
abstract class GmailRepository {
  Future<List<GmailAccount>> getAccounts();

  /// Opens the backend-controlled OAuth consent flow.
  Future<String> getConnectUrl();

  Future<GmailSyncResult> sync({bool fullSync = false});

  Future<List<GmailThread>> getThreads({String? applicationId});

  Future<GmailThread> getThread(String threadId);

  Future<GmailMessage> getMessage(String messageId);

  Future<GmailMatchResult> confirmMatch(
    String threadId,
    GmailMatchConfirm confirm,
  );

  Future<GmailMatchResult> ignoreMatch(String threadId);

  Future<GmailMatchResult> unlinkMatch(String threadId);

  Future<List<GmailTimelineEvent>> getApplicationTimeline(String applicationId);

  /// Revokes access and deletes stored credentials. Applications, status
  /// history and user notes are untouched.
  Future<void> disconnect(String accountId);
}

/// An explicit, user-authored decision about a matched email.
///
/// Omitting [status] links the email without touching application status;
/// omitting [interview] does not create an interview. Both are opt-in, which
/// is what makes "never change status automatically" enforceable.
class GmailMatchConfirm {
  const GmailMatchConfirm({
    required this.applicationId,
    this.status,
    this.interview,
    this.forceInterview = false,
  });

  final String applicationId;
  final String? status;
  final InterviewDraft? interview;

  /// Set only after the user acknowledges an interview scheduling conflict.
  final bool forceInterview;
}

/// The interview the user chose to create from an email.
class InterviewDraft {
  const InterviewDraft({
    this.type,
    this.interviewType,
    this.title,
    required this.scheduledAt,
    this.durationMinutes = 60,
    this.meetingUrl,
    this.location,
    this.interviewerName,
    this.interviewerEmail,
  });

  final String? type;
  final String? interviewType;
  final String? title;
  final DateTime scheduledAt;
  final int durationMinutes;
  final String? meetingUrl;
  final String? location;
  final String? interviewerName;
  final String? interviewerEmail;

  Map<String, dynamic> toJson() {
    final resolved = interviewType ?? type;
    return {
      'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      'type': ?resolved,
      'interview_type': ?resolved,
      'title': ?title,
      'duration_minutes': durationMinutes,
      'meeting_url': ?meetingUrl,
      'location': ?location,
      'interviewer_name': ?interviewerName,
      'interviewer_email': ?interviewerEmail,
    };
  }
}
