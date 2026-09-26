import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Deep links that open this app's entry in the OS notification settings.
///
/// `flutter_local_notifications` and `firebase_messaging` expose no API for
/// this, and `permission_handler` is not a dependency, so the platform's
/// documented settings URLs are used instead. Both are documented public
/// scheme handlers:
///  * Android: `package:` resolves to the app's details page, from which
///    "Notifications" is one tap away.
///  * iOS: `app-settings:` opens this app's settings pane.
/// Android package, kept in step with `applicationId` in
/// `android/app/build.gradle.kts`. The `package:` scheme opens the app's details
/// page, from which "Notifications" is one tap away.
const androidPackageName = 'com.jobtracker.job_tracker';

const _androidSettingsUrl = 'package:$androidPackageName';
const _iosSettingsUrl = 'app-settings:';

/// Opens the system notification settings for this app.
///
/// Returns false when the platform has no known settings URL or the OS refuses
/// to handle it, so the caller can explain the failure instead of silently
/// doing nothing.
Future<bool> openSystemNotificationSettings() async {
  final uri = switch (defaultTargetPlatform) {
    TargetPlatform.android => _androidSettingsUrl,
    TargetPlatform.iOS => _iosSettingsUrl,
    TargetPlatform.fuchsia ||
    TargetPlatform.linux ||
    TargetPlatform.macOS ||
    TargetPlatform.windows => null,
  };
  if (uri == null) return false;
  try {
    return await launchUrl(
      Uri.parse(uri),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}
