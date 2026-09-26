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
  });

  final String applicationId;
  final String? status;
  final InterviewDraft? interview;
}

/// The interview the user chose to create from an email.
class InterviewDraft {
  const InterviewDraft({
    this.type,
    this.title,
    required this.scheduledAt,
    this.durationMinutes = 60,
    this.meetingUrl,
    this.interviewerName,
  });

  final String? type;
  final String? title;
  final DateTime scheduledAt;
  final int durationMinutes;
  final String? meetingUrl;
  final String? interviewerName;

  Map<String, dynamic> toJson() => {
    'scheduled_at': scheduledAt.toUtc().toIso8601String(),
    if (type != null) 'type': type,
    if (title != null) 'title': title,
    'duration_minutes': durationMinutes,
    if (meetingUrl != null) 'meeting_url': meetingUrl,
    if (interviewerName != null) 'interviewer_name': interviewerName,
  };
}
