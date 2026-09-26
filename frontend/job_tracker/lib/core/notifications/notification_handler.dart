import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'fcm_service.dart';
import 'notification_payload.dart';
import 'notification_router_core.dart';

export 'notification_payload.dart' show NotificationPayloadKeys;

/// Receives a destination that the app shell should navigate to.
typedef NotificationTapHandler =
    void Function(NotificationDestination destination);

/// Bridges FCM callbacks to in-app navigation.
///
/// Deliberately holds no `BuildContext` and no router: it converts payloads
/// into [NotificationDestination] values and hands them to a callback the app
/// installs. That keeps the parsing logic testable and avoids capturing a
/// context across isolates.
class NotificationHandler {
  NotificationHandler({NotificationRouter router = const NotificationRouter()})
    : _router = router;

  final NotificationRouter _router;
  final _foregroundController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _tapController = StreamController<NotificationDestination>.broadcast();

  final _initialized = Completer<void>();
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  bool _disposed = false;

  /// True once [initialize] has completed (successfully or not).
  Future<void> get ready => _initialized.future;

  /// Payloads for messages shown while the app is in the foreground.
  Stream<Map<String, dynamic>> get onForegroundMessage =>
      _foregroundController.stream;

  /// Destinations for taps on a system notification.
  Stream<NotificationDestination> get onNotificationTap =>
      _tapController.stream;

  /// Attaches handlers. Safe to call once per app lifecycle.
  Future<void> initialize({
    required FcmServiceAdapter adapter,
    NotificationTapHandler? onTap,
  }) async {
    if (_disposed) return;

    if (onTap != null) {
      _tapController.stream.listen(onTap);
    }

    try {
      await adapter.initialize();

      // A notification that launched the app is the highest-priority intent
      // and must be handled before the first frame.
      final initial = await adapter.initialMessage();
      if (initial != null) {
        _handleTap(initial.data);
      }

      _messageSubscription = adapter.onForegroundMessage().listen((message) {
        final payload = Map<String, dynamic>.from(message.data);
        // FCM carries display text in a separate `notification` block, so a
        // data-only view of the message leaves the in-app banner with nothing
        // to render. Merge it in without letting it override explicit data.
        _fillFromNotificationBlock(payload, message.notification);
        if (payload.isEmpty) return;
        // Delivery must never move the user: a foreground message is published
        // for the banner to display. Navigation happens only when the banner
        // itself is tapped, via [handleExternalPayload].
        _foregroundController.add(payload);
      });

      _tokenSubscription = adapter.onTokenRefresh().listen((token) {
        if (token.isEmpty) return;
        _tokenController.add(token);
      });
    } catch (error) {
      debugPrint('NotificationHandler.initialize failed: ${error.runtimeType}');
    } finally {
      if (!_initialized.isCompleted) _initialized.complete();
    }
  }

  final _tokenController = StreamController<String>.broadcast();

  /// Fills missing `title`/`body` from the FCM notification block.
  ///
  /// Data-only sends already carry these, and a caller who set them
  /// deliberately must keep them, so existing values always win.
  static void _fillFromNotificationBlock(
    Map<String, dynamic> payload,
    RemoteNotification? notification,
  ) {
    if (notification == null) return;
    for (final entry in {
      NotificationPayloadKeys.title: notification.title,
      NotificationPayloadKeys.body: notification.body,
    }.entries) {
      final existing = payload[entry.key]?.toString().trim();
      if (existing != null && existing.isNotEmpty) continue;
      final value = entry.value?.trim();
      if (value != null && value.isNotEmpty) payload[entry.key] = value;
    }
  }

  /// New FCM tokens that must be re-registered with the backend.
  Stream<String> get onTokenRefresh => _tokenController.stream;

  void _handleTap(Map<String, dynamic> data) {
    final destination = _router.resolve(data);
    if (destination == null) return;
    if (!_tapController.isClosed) _tapController.add(destination);
  }

  /// Routes a payload the user explicitly tapped.
  ///
  /// Used by the in-app banner, the notification centre, and platform
  /// deep-links (e.g. the Gmail OAuth redirect). Nothing calls this as a
  /// side-effect of merely receiving a message.
  void handleExternalPayload(Map<String, dynamic> data) => _handleTap(data);

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _foregroundController.close();
    await _tapController.close();
    await _tokenController.close();
  }
}

/// Thin seam over the FCM SDK so [NotificationHandler] stays testable without
/// a real Firebase instance.
abstract class FcmServiceAdapter {
  Future<void> initialize();

  Stream<String> onTokenRefresh();

  Stream<RemoteMessage> onForegroundMessage();

  /// Whether the app shows its own in-foreground banner (i.e. the OS does not
  /// draw a notification for foreground messages on this platform).
  bool get presentedInForeground;

  /// The message that cold-started the app from a notification tap, if any.
  Future<RemoteMessage?> initialMessage() => FcmService.getInitialMessage();
}
