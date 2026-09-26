import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Thrown when the platform cannot deliver push notifications at all.
class FcmUnavailableException implements Exception {
  const FcmUnavailableException(this.reason);
  final String reason;

  @override
  String toString() => 'FcmUnavailableException: $reason';
}

/// Outcome of a push-permission request.
///
/// The app must keep working in every one of these states; notifications are
/// strictly an enhancement.
enum NotificationPermissionStatus {
  /// User has not been asked yet, or has not answered this session.
  undetermined,

  /// Push may be delivered.
  granted,

  /// User declined, but asking again is still allowed.
  denied,

  /// User chose "don't ask again" (Android 13+). Only Settings can change it.
  permanentlyDenied,
}

/// Firebase Cloud Messaging registration, token retrieval, and refresh.
///
/// This class owns the FCM SDK surface. It never talks to the backend — device
/// registration is the caller's job (see `DeviceRegistrationService`), which
/// keeps "get a token" and "persist a token" independently testable.
class FcmService {
  FcmService({FirebaseMessaging? messaging}) : _messaging = messaging;

  final FirebaseMessaging? _messaging;

  /// The injected instance when a test supplied one, otherwise the real SDK.
  ///
  /// Resolution is lazy so that constructing [FcmService] on an unsupported
  /// platform (or before `Firebase.initializeApp`) is not itself an error.
  FirebaseMessaging get _messagingInstance {
    final injected = _messaging;
    if (injected != null) return injected;
    try {
      return FirebaseMessaging.instance;
    } catch (_) {
      throw const FcmUnavailableException(
        'firebase_messaging is not available on this platform.',
      );
    }
  }

  /// True when a push-capable target is running.
  ///
  /// Web is intentionally excluded: the device model is specified as
  /// ANDROID/IOS only, and silently registering a WEB token against a model
  /// that cannot represent it would be misleading.
  static bool get isSupportedPlatform {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return false;
    }
  }

  /// Whether this is a platform FCM actually supports.
  static bool get isPlatformSupported => !kIsWeb && isSupportedPlatform;

  /// Instance form of [isSupportedPlatform].
  ///
  /// Reads through an instance rather than the static so that the
  /// device-registration controller depends on the abstraction it was handed
  /// and can be exercised on a test platform.
  bool get isSupported => isSupportedPlatform;

  /// Must be called before any other method. Safe to call more than once.
  ///
  /// Errors are swallowed: a device that cannot receive push must still be
  /// able to use the rest of the app.
  Future<void> initialize() async {
    if (!isSupported) return;
    try {
      // Foreground messages: show a local notification only when the user is
      // actually looking at the app, otherwise it is a duplicate of the
      // system tray notification.
      await _messagingInstance.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );
    } catch (_) {
      // Older SDKs / unsupported presentation options — non-fatal.
    }
  }

  /// Asks the OS for permission, honouring "don't ask again".
  ///
  /// [askedBefore] must reflect whether the user has ever been prompted. FCM
  /// cannot distinguish "declined this time" from "chose don't ask again" on
  /// its own: both report [AuthorizationStatus.denied]. Only the prior prompt
  /// makes the difference, and it is the caller's job to remember it across
  /// launches (see `DeviceRegistrationService`).
  Future<NotificationPermissionStatus> requestPermission({
    bool askedBefore = false,
  }) async {
    if (!isSupported) return NotificationPermissionStatus.denied;
    try {
      final settings = await _messagingInstance.requestPermission();
      return fromAuthorizationStatus(
        settings.authorizationStatus,
        askedBefore: askedBefore,
      );
    } catch (_) {
      return NotificationPermissionStatus.denied;
    }
  }

  /// Current permission without prompting the user.
  Future<NotificationPermissionStatus> checkPermission({
    bool askedBefore = false,
  }) async {
    if (!isSupported) return NotificationPermissionStatus.denied;
    try {
      final settings = await _messagingInstance.getNotificationSettings();
      return fromAuthorizationStatus(
        settings.authorizationStatus,
        askedBefore: askedBefore,
      );
    } catch (_) {
      return NotificationPermissionStatus.denied;
    }
  }

  /// The current FCM registration token, or null when unavailable.
  ///
  /// Never log or persist this anywhere except the device-registration call.
  Future<String?> getToken() async {
    if (!isSupported) return null;
    try {
      return await _messagingInstance.getToken();
    } catch (_) {
      return null;
    }
  }

  /// Fires whenever the OS rotates the token.
  ///
  /// FCM tokens are not permanent; the app must re-register on every change or
  /// pushes silently stop arriving.
  Stream<String> onTokenRefresh() {
    if (!isSupported) return const Stream<String>.empty();
    try {
      return _messagingInstance.onTokenRefresh;
    } catch (_) {
      return const Stream<String>.empty();
    }
  }

  /// Messages delivered while the app is in the foreground.
  Stream<RemoteMessage> onForegroundMessage() {
    if (!isSupported) return const Stream<RemoteMessage>.empty();
    try {
      return FirebaseMessaging.onMessage;
    } catch (_) {
      return const Stream<RemoteMessage>.empty();
    }
  }

  /// Tapping a notification while the app is in the background or terminated.
  ///
  /// This can resolve before `FirebaseMessaging.instance` is usable, so it is
  /// exposed as a top-level getter for the background isolate.
  static Future<RemoteMessage?> getInitialMessage() async {
    try {
      return await FirebaseMessaging.instance.getInitialMessage();
    } catch (_) {
      return null;
    }
  }

  /// Whether a notification opened the app from the system tray.
  static bool openedFromNotification(RemoteMessage message) {
    return message.messageId != null;
  }

  /// Maps the FCM authorization status onto the app's own model.
  ///
  /// A denial that follows an earlier prompt is treated as permanent: on
  /// Android 13+ and on iOS the system stops showing the prompt after the user
  /// declines twice, so re-asking would be a no-op and Settings is the only way
  /// back. A first-time denial stays [NotificationPermissionStatus.denied] so
  /// the UI does not send users to Settings unnecessarily.
  static NotificationPermissionStatus fromAuthorizationStatus(
    AuthorizationStatus status, {
    bool askedBefore = false,
  }) {
    switch (status) {
      case AuthorizationStatus.authorized:
      case AuthorizationStatus.provisional:
        return NotificationPermissionStatus.granted;
      case AuthorizationStatus.denied:
        return askedBefore
            ? NotificationPermissionStatus.permanentlyDenied
            : NotificationPermissionStatus.denied;
      case AuthorizationStatus.notDetermined:
        return NotificationPermissionStatus.undetermined;
    }
  }
}
