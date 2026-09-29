import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';

import 'notification_service.dart';

/// Top-level handler for messages delivered while the app is backgrounded or
/// terminated.
///
/// FCM spins up a fresh isolate for this, so it must be a top-level function
/// annotated with `vm:entry-point` and it cannot touch Riverpod, the router or
/// any other app state. All it can do is draw a system notification; the tap
/// is handled later by the foreground app through the stored payload.
///
/// Registered in `main()` via
/// `FirebaseMessaging.onBackgroundMessage(backgroundMessageHandler)`.
@pragma('vm:entry-point')
Future<void> backgroundMessageHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  final service = NotificationService();
  await service.initialize();
  await service.presentRemoteMessage(message);
}
