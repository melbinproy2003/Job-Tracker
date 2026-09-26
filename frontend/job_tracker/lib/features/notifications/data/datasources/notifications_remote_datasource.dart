import 'package:dio/dio.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/app_notification.dart';
import '../models/notification_model.dart';
import '../models/notification_preferences_model.dart';

/// Result of registering this device's FCM token with the backend.
class DeviceRegistrationResult {
  const DeviceRegistrationResult({
    required this.id,
    required this.platform,
    required this.isActive,
  });

  final String id;
  final String platform;
  final bool isActive;
}

/// Talks to `/api/v1/notifications`.
///
/// The device token is sent straight to the backend and never cached on the
/// device: Firebase already owns it, and a stale copy in local storage is a
/// liability rather than an optimisation.
class NotificationsRemoteDataSource {
  NotificationsRemoteDataSource(this._dio);
  final Dio _dio;

  Future<List<AppNotification>> list() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiEndpoints.notifications,
      );
      return (response.data ?? [])
          .map(
            (e) => NotificationModel.fromJson(
              e as Map<String, dynamic>,
            ).toEntity(),
          )
          .toList();
    } on DioException catch (e) {
      ApiException.throwFromDio(e);
    }
  }

  Future<int> unreadCount() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.notificationsUnreadCount,
      );
      return (response.data?['count'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      ApiException.throwFromDio(e);
    }
  }

  Future<AppNotification> markRead(String id) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiEndpoints.notificationRead(id),
      );
      return NotificationModel.fromJson(response.data!).toEntity();
    } on DioException catch (e) {
      ApiException.throwFromDio(e);
    }
  }

  Future<int> markAllRead() async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiEndpoints.notificationsReadAll,
      );
      return (response.data?['updated'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      ApiException.throwFromDio(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete(ApiEndpoints.notification(id));
    } on DioException catch (e) {
      ApiException.throwFromDio(e);
    }
  }

  Future<NotificationPreferencesModel> getPreferences() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.notificationPreferences,
      );
      return NotificationPreferencesModel.fromJson(response.data ?? const {});
    } on DioException catch (e) {
      ApiException.throwFromDio(e);
    }
  }

  Future<NotificationPreferencesModel> updatePreferences(
    NotificationPreferencesModel preferences,
  ) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        ApiEndpoints.notificationPreferences,
        data: preferences.toJson(),
      );
      return NotificationPreferencesModel.fromJson(response.data ?? const {});
    } on DioException catch (e) {
      ApiException.throwFromDio(e);
    }
  }

  /// Registers (or re-registers) this device's FCM token.
  ///
  /// Called on sign-in and again on every token refresh, so the backend always
  /// holds the current token for this install.
  Future<DeviceRegistrationResult> registerDevice({
    required String fcmToken,
    required String platform,
    String? deviceName,
    String? appVersion,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.notificationDevices,
        data: {
          'fcm_token': fcmToken,
          'platform': platform,
          'device_name': ?deviceName,
          'app_version': ?appVersion,
        },
      );
      final data = response.data ?? const <String, dynamic>{};
      return DeviceRegistrationResult(
        id: data['id']?.toString() ?? '',
        platform: data['platform']?.toString() ?? platform,
        isActive: data['is_active'] as bool? ?? true,
      );
    } on DioException catch (e) {
      ApiException.throwFromDio(e);
    }
  }

  Future<void> deleteDevice(String deviceId) async {
    try {
      await _dio.delete(ApiEndpoints.notificationDevice(deviceId));
    } on DioException catch (e) {
      ApiException.throwFromDio(e);
    }
  }
}
