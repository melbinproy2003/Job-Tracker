import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import '../notifications/fcm_service.dart';

/// Firebase app initialization wrapper.
///
/// Safe for hot restart and Android auto-init via `google-services.json`.
class FirebaseService {
  /// True on the platforms this project targets for push (Android and iOS).
  ///
  /// Mirrors `FcmService.isSupportedPlatform`; kept here so `main()` does not
  /// need to reach into the notification feature to decide whether to register
  /// the background handler.
  static bool get isSupportedPlatform => FcmService.isSupportedPlatform;

  Future<void> initialize() async {
    // Dart-side apps list can be empty after hot restart even when the
    // native DEFAULT app already exists — catch duplicate-app below.
    if (Firebase.apps.isNotEmpty) {
      return;
    }

    if (!DefaultFirebaseOptions.isConfigured) {
      debugPrint(
        'Firebase options are placeholders. Run `flutterfire configure` '
        'before testing Google Sign-In.',
      );
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (e) {
      if (e.code == 'duplicate-app') {
        // Already created by native layer or a previous hot-restart cycle.
        debugPrint('Firebase DEFAULT app already exists; reusing it.');
        return;
      }
      rethrow;
    }
  }
}
