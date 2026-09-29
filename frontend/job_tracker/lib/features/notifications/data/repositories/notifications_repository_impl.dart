import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../datasources/notifications_remote_datasource.dart';
import '../models/notification_preferences_model.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl(this._remote);
  final NotificationsRemoteDataSource _remote;

  @override
  Future<List<AppNotification>> getAll() => _remote.list();

  @override
  Future<int> unreadCount() => _remote.unreadCount();

  @override
  Future<AppNotification> markRead(String id) => _remote.markRead(id);

  @override
  Future<int> markAllRead() => _remote.markAllRead();

  @override
  Future<void> delete(String id) => _remote.delete(id);

  @override
  Future<NotificationPreferences> getPreferences() async {
    final model = await _remote.getPreferences();
    return _toEntity(model);
  }

  @override
  Future<NotificationPreferences> updatePreferences(
    NotificationPreferences preferences,
  ) async {
    final model = await _remote.updatePreferences(_fromEntity(preferences));
    return _toEntity(model);
  }

  @override
  Future<String> registerDevice({
    required String fcmToken,
    required String platform,
    String? deviceName,
    String? appVersion,
  }) async {
    final result = await _remote.registerDevice(
      fcmToken: fcmToken,
      platform: platform,
      deviceName: deviceName,
      appVersion: appVersion,
    );
    return result.id;
  }

  @override
  Future<void> unregisterDevice(String deviceId) =>
      _remote.deleteDevice(deviceId);

  static NotificationPreferences _toEntity(
    NotificationPreferencesModel model,
  ) => NotificationPreferences(
    interviewReminders: model.interviewReminders,
    followupReminders: model.followupReminders,
    overdueFollowups: model.overdueFollowups,
    gmailNotifications: model.gmailNotifications,
    applicationSuggestions: model.applicationSuggestions,
  );

  static NotificationPreferencesModel _fromEntity(
    NotificationPreferences prefs,
  ) => NotificationPreferencesModel(
    interviewReminders: prefs.interviewReminders,
    followupReminders: prefs.followupReminders,
    overdueFollowups: prefs.overdueFollowups,
    gmailNotifications: prefs.gmailNotifications,
    applicationSuggestions: prefs.applicationSuggestions,
  );
}
