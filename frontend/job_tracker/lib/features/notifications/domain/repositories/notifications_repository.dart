import '../../domain/entities/app_notification.dart';

/// Domain contract for the notification centre, device registration and
/// reminder preferences.
abstract class NotificationRepository {
  Future<List<AppNotification>> getAll();

  Future<int> unreadCount();

  Future<AppNotification> markRead(String id);

  Future<int> markAllRead();

  Future<void> delete(String id);

  Future<NotificationPreferences> getPreferences();

  Future<NotificationPreferences> updatePreferences(
    NotificationPreferences preferences,
  );

  Future<String> registerDevice({
    required String fcmToken,
    required String platform,
    String? deviceName,
    String? appVersion,
  });

  Future<void> unregisterDevice(String deviceId);
}

/// User-tunable notification switches. All default to enabled.
class NotificationPreferences {
  const NotificationPreferences({
    this.interviewReminders = true,
    this.followupReminders = true,
    this.overdueFollowups = true,
    this.gmailNotifications = true,
    this.applicationSuggestions = true,
  });

  final bool interviewReminders;
  final bool followupReminders;
  final bool overdueFollowups;
  final bool gmailNotifications;
  final bool applicationSuggestions;

  NotificationPreferences copyWith({
    bool? interviewReminders,
    bool? followupReminders,
    bool? overdueFollowups,
    bool? gmailNotifications,
    bool? applicationSuggestions,
  }) {
    return NotificationPreferences(
      interviewReminders: interviewReminders ?? this.interviewReminders,
      followupReminders: followupReminders ?? this.followupReminders,
      overdueFollowups: overdueFollowups ?? this.overdueFollowups,
      gmailNotifications: gmailNotifications ?? this.gmailNotifications,
      applicationSuggestions:
          applicationSuggestions ?? this.applicationSuggestions,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationPreferences &&
      other.interviewReminders == interviewReminders &&
      other.followupReminders == followupReminders &&
      other.overdueFollowups == overdueFollowups &&
      other.gmailNotifications == gmailNotifications &&
      other.applicationSuggestions == applicationSuggestions;

  @override
  int get hashCode => Object.hash(
    interviewReminders,
    followupReminders,
    overdueFollowups,
    gmailNotifications,
    applicationSuggestions,
  );
}
