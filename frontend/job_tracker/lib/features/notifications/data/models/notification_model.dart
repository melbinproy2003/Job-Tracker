import '../../../../core/enums/notification_type.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/app_notification.dart';

/// Wire format for [AppNotification].
class NotificationModel {
  NotificationModel.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      type = AppNotificationType.fromApi(json['type']?.toString() ?? 'SYSTEM'),
      title = json['title'] as String? ?? '',
      body = json['body'] as String? ?? '',
      data = (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
      relatedApplicationId = json['related_application_id'] as String?,
      relatedInterviewId = json['related_interview_id'] as String?,
      relatedFollowupId = json['related_followup_id'] as String?,
      read = json['read'] as bool? ?? false,
      sentAt = parseApiDateTime(json['sent_at']),
      createdAt = parseApiDateTime(json['created_at']),
      expiresAt = parseApiDateTime(json['expires_at']);

  final String id;
  final AppNotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final String? relatedApplicationId;
  final String? relatedInterviewId;
  final String? relatedFollowupId;
  final bool read;
  final DateTime? sentAt;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  AppNotification toEntity() => AppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    data: data,
    relatedApplicationId: relatedApplicationId,
    relatedInterviewId: relatedInterviewId,
    relatedFollowupId: relatedFollowupId,
    read: read,
    sentAt: sentAt,
    createdAt: createdAt,
    expiresAt: expiresAt,
  );
}
