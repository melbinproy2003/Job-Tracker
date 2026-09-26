import '../../../../core/enums/notification_type.dart';

/// A single in-app / push notification.
///
/// Domain entity: no JSON, no Dio, no Firestore.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.data = const {},
    this.relatedApplicationId,
    this.relatedInterviewId,
    this.relatedFollowupId,
    this.read = false,
    this.sentAt,
    this.createdAt,
    this.expiresAt,
  });

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

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      data: data,
      relatedApplicationId: relatedApplicationId,
      relatedInterviewId: relatedInterviewId,
      relatedFollowupId: relatedFollowupId,
      read: read ?? this.read,
      sentAt: sentAt,
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }

  /// Rebuilds the deep-link payload the backend would have pushed for this
  /// notification, so a row tapped in the inbox routes exactly like the same
  /// notification tapped from the system tray.
  Map<String, dynamic> toPayload() {
    return {
      'type': type.apiValue,
      'notification_id': id,
      ...data,
      if (relatedApplicationId != null) 'application_id': relatedApplicationId,
      if (relatedInterviewId != null) 'interview_id': relatedInterviewId,
      if (relatedFollowupId != null) 'followup_id': relatedFollowupId,
    };
  }
}
