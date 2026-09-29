import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/constants/app_env.dart';
import 'core/firebase/firebase_service.dart';
import 'core/notifications/notification_background_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppEnv.load();
  await FirebaseService().initialize();

  // Must be registered before `runApp`: a message can be delivered while the
  // app is terminated, in which case FCM spins up its own isolate to run this
  // top-level handler. Registering later would miss those.
  if (FirebaseService.isSupportedPlatform) {
    FirebaseMessaging.onBackgroundMessage(backgroundMessageHandler);
  }

  runApp(const ProviderScope(child: JobTrackerApp()));
}
