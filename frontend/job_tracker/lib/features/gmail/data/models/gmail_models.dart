import '../../../../core/enums/application_status.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/gmail_thread.dart';

/// Parses an optional status without collapsing `null` into a real value.
///
/// `ApplicationStatus.fromApi` is non-nullable and falls back to `applied`,
/// which is fine for a stored status but wrong here: a thread with no
/// suggestion must stay "no suggestion", never silently become "Applied".
ApplicationStatus? _optionalStatus(dynamic raw) {
  if (raw == null) return null;
  final value = raw.toString();
  for (final status in ApplicationStatus.values) {
    if (status.apiValue == value) return status;
  }
  return null;
}

class GmailAccountModel {
  GmailAccountModel.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      email = json['email'] as String? ?? '',
      connected = json['connected'] as bool? ?? true,
      lastSyncAt = parseApiDateTime(json['last_sync_at']),
      scopes =
          (json['scopes'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[];

  final String id;
  final String email;
  final bool connected;
  final DateTime? lastSyncAt;
  final List<String> scopes;

  GmailAccount toEntity() => GmailAccount(
    id: id,
    email: email,
    connected: connected,
    lastSyncAt: lastSyncAt,
    scopes: scopes,
  );
}

class GmailThreadModel {
  GmailThreadModel.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      gmailThreadId = json['gmail_thread_id'] as String? ?? '',
      subject = json['subject'] as String?,
      snippet = json['snippet'] as String?,
      participants =
          (json['participants'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      lastMessageAt = parseApiDateTime(json['last_message_at']),
      applicationId = json['application_id'] as String?,
      matchStatus = GmailMatchStatus.fromApi(json['match_status']?.toString()),
      isJobRelated = json['is_job_related'] as bool? ?? false,
      suggestedStatus = _optionalStatus(json['suggested_status']),
      matchConfidence = (json['match_confidence'] as num?)?.toInt(),
      interviewSuggestion = _interview(json['interview_suggestion']);

  final String id;
  final String gmailThreadId;
  final String? subject;
  final String? snippet;
  final List<String> participants;
  final DateTime? lastMessageAt;
  final String? applicationId;
  final GmailMatchStatus matchStatus;
  final bool isJobRelated;
  final ApplicationStatus? suggestedStatus;
  final int? matchConfidence;
  final InterviewSuggestion? interviewSuggestion;

  static InterviewSuggestion? _interview(dynamic raw) {
    if (raw is! Map) return null;
    return InterviewSuggestion.fromJson(raw.cast<String, dynamic>());
  }

  GmailThread toEntity() => GmailThread(
    id: id,
    gmailThreadId: gmailThreadId,
    subject: subject,
    snippet: snippet,
    participants: participants,
    lastMessageAt: lastMessageAt,
    applicationId: applicationId,
    matchStatus: matchStatus,
    isJobRelated: isJobRelated,
    suggestedStatus: suggestedStatus?.apiValue,
    matchConfidence: matchConfidence,
    interviewSuggestion: interviewSuggestion,
  );
}

class GmailMessageModel {
  GmailMessageModel.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      gmailMessageId = json['gmail_message_id'] as String? ?? '',
      gmailThreadId = json['gmail_thread_id'] as String? ?? '',
      fromAddress = json['from_address'] as String?,
      toAddress = json['to_address'] as String?,
      subject = json['subject'] as String?,
      snippet = json['snippet'] as String?,
      receivedAt = parseApiDateTime(json['received_at']),
      bodyText = json['body_text'] as String?,
      applicationId = json['application_id'] as String?,
      isJobRelated = json['is_job_related'] as bool? ?? false,
      detectedCategory = json['detected_category'] as String?;

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

  GmailMessage toEntity() => GmailMessage(
    id: id,
    gmailMessageId: gmailMessageId,
    gmailThreadId: gmailThreadId,
    fromAddress: fromAddress,
    toAddress: toAddress,
    subject: subject,
    snippet: snippet,
    receivedAt: receivedAt,
    bodyText: bodyText,
    applicationId: applicationId,
    isJobRelated: isJobRelated,
    detectedCategory: detectedCategory,
  );
}

class GmailSyncResultModel {
  GmailSyncResultModel.fromJson(Map<String, dynamic> json)
    : success = json['success'] as bool? ?? true,
      messagesChecked = (json['messages_checked'] as num?)?.toInt() ?? 0,
      jobRelatedFound = (json['job_related_found'] as num?)?.toInt() ?? 0,
      matchesSuggested = (json['matches_suggested'] as num?)?.toInt() ?? 0,
      lastSyncAt = parseApiDateTime(json['last_sync_at']),
      message = json['message'] as String?;

  final bool success;
  final int messagesChecked;
  final int jobRelatedFound;
  final int matchesSuggested;
  final DateTime? lastSyncAt;
  final String? message;

  GmailSyncResult toEntity() => GmailSyncResult(
    success: success,
    messagesChecked: messagesChecked,
    jobRelatedFound: jobRelatedFound,
    matchesSuggested: matchesSuggested,
    lastSyncAt: lastSyncAt,
    message: message,
  );
}

class GmailMatchResultModel {
  GmailMatchResultModel.fromJson(Map<String, dynamic> json)
    : threadId = json['thread_id'] as String? ?? '',
      applicationId = json['application_id'] as String?,
      matchStatus = GmailMatchStatus.fromApi(json['match_status']?.toString()),
      suggestedStatus = json['suggested_status']?.toString(),
      applied = json['applied'] as bool? ?? false,
      interviewCreated = json['interview_created'] as bool? ?? false;

  final String threadId;
  final String? applicationId;
  final GmailMatchStatus matchStatus;
  final String? suggestedStatus;
  final bool applied;
  final bool interviewCreated;

  GmailMatchResult toEntity() => GmailMatchResult(
    threadId: threadId,
    applicationId: applicationId,
    matchStatus: matchStatus,
    suggestedStatus: suggestedStatus,
    applied: applied,
    interviewCreated: interviewCreated,
  );
}
