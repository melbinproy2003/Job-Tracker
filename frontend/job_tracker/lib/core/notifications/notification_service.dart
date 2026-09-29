import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_payload.dart';

/// Draws system notifications and reports taps back to the app.
///
/// Two situations need a locally drawn notification:
///  * a message that arrives while the app is in the foreground, where the OS
///    stays silent and the user would otherwise see nothing;
///  * a data-only message that arrives in the background isolate, where no
///    tray notification is produced for us.
///
/// Taps are surfaced as the original payload map so that the router can send
/// the user to the same destination as an inbox tap.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  void Function(Map<String, dynamic> payload)? _onTap;

  static const _channelId = 'job_tracker_notifications';
  static const _channelName = 'Job Tracker notifications';

  /// Prepares the notification channel and installs the tap callback.
  ///
  /// The platform is never asked for permission here: FCM owns that decision
  /// (see `FcmService`), and asking twice is a Play Store anti-pattern.
  /// Failure is non-fatal, because notifications are an enhancement.
  Future<void> initialize({
    void Function(Map<String, dynamic> payload)? onTap,
    String androidIcon = '@mipmap/ic_launcher',
  }) async {
    _onTap = onTap;
    if (_initialized) return;
    try {
      await _plugin.initialize(
        settings: InitializationSettings(
          android: AndroidInitializationSettings(androidIcon),
          iOS: const DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: _handleResponse,
      );
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'Interview and follow-up reminders',
          importance: Importance.high,
        ),
      );
      _initialized = true;
    } catch (error) {
      debugPrint('Local notifications unavailable: ${error.runtimeType}');
    }
  }

  void _handleResponse(NotificationResponse response) {
    final raw = response.payload;
    if (raw == null || raw.isEmpty) return;
    final callback = _onTap;
    if (callback == null) {
      debugPrint('Local notification tapped with no handler attached');
      return;
    }
    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(raw);
      payload = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : {'type': raw};
    } catch (_) {
      // Payloads written by older builds were a bare type string.
      payload = {'type': raw};
    }
    callback(payload);
  }

  /// Stable notification id so a re-render does not stack duplicates.
  int _idFor(Map<String, dynamic> data) {
    final id = data[NotificationPayloadKeys.notificationId]?.toString();
    if (id != null && id.isNotEmpty) return id.hashCode;
    final type = data[NotificationPayloadKeys.type]?.toString();
    if (type != null && type.isNotEmpty) return type.hashCode;
    return DateTime.now().millisecondsSinceEpoch;
  }

  /// Draws a notification carrying [data] as its deep-link payload.
  Future<void> show(
    Map<String, dynamic> data, {
    required String title,
    required String body,
  }) async {
    if (!_initialized) await initialize();
    try {
      await _plugin.show(
        id: _idFor(data),
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        // The full payload, so a tap routes identically to an inbox tap.
        payload: jsonEncode(data),
      );
    } catch (error) {
      debugPrint('Could not display notification: ${error.runtimeType}');
    }
  }

  /// Shows a notification for a message received while the app is visible.
  Future<void> showForegroundNotification(
    Map<String, dynamic> data, {
    required String title,
    required String body,
  }) => show(data, title: title, body: body);

  /// Shows a notification for a data-only message handled in the background
  /// isolate.
  ///
  /// Messages that already carry a `notification` block are skipped: the OS
  /// draws those itself, and drawing a second one would double them up.
  Future<void> presentRemoteMessage(RemoteMessage message) async {
    if (message.notification != null) return;
    final data = message.data;
    final title = data['title']?.toString().trim();
    if (title == null || title.isEmpty) return;
    await show(data, title: title, body: data['body']?.toString() ?? '');
  }
}
