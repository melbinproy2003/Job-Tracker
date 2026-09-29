import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/notifications/fcm_service.dart';

/// Remembers whether we have already asked the OS for notification permission.
///
/// FCM permission prompts are heavily penalised by the Play Store: asking
/// again after a refusal is treated as bad practice. The choice is therefore
/// made once per install and then respected, and the user is directed to
/// system Settings when they have blocked us.
///
/// The flag is install-scoped, not user-scoped, because the OS permission is
/// granted to the app rather than to an account: signing in as somebody else
/// on the same device does not re-arm the prompt.
abstract class NotificationPermissionStore {
  Future<bool> wasAsked();

  Future<void> markAsked();
}

/// In-memory store. Used by tests and as the fallback when storage is
/// unavailable.
class InMemoryNotificationPermissionStore
    implements NotificationPermissionStore {
  InMemoryNotificationPermissionStore([bool asked = false]) : _asked = asked;

  bool _asked;

  @override
  Future<bool> wasAsked() async => _asked;

  @override
  Future<void> markAsked() async => _asked = true;
}

/// Persists the flag across launches.
///
/// `flutter_secure_storage` is already a dependency, and the value is a
/// one-bit preference rather than a credential, so no new package is needed.
class SecureNotificationPermissionStore implements NotificationPermissionStore {
  SecureNotificationPermissionStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _key = 'notification_permission_asked_v1';

  bool? _cached;

  @override
  Future<bool> wasAsked() async {
    final cached = _cached;
    if (cached != null) return cached;
    try {
      final value = await _storage.read(key: _key);
      final asked = value == 'true';
      _cached = asked;
      return asked;
    } catch (_) {
      // Assume "not asked": worst case is a single extra prompt.
      return false;
    }
  }

  @override
  Future<void> markAsked() async {
    _cached = true;
    try {
      await _storage.write(key: _key, value: 'true');
    } catch (_) {
      // Losing the flag must never stop the app from starting.
    }
  }
}

/// What the UI needs to know about push state on this device.
class PushRegistrationState {
  const PushRegistrationState({
    this.permission = NotificationPermissionStatus.undetermined,
    this.registered = false,
    this.deviceId,
    this.isSupported = true,
    this.busy = false,
    this.error,
  });

  final NotificationPermissionStatus permission;
  final bool registered;
  final String? deviceId;
  final bool isSupported;
  final bool busy;
  final String? error;

  bool get canReceivePush =>
      isSupported && permission == NotificationPermissionStatus.granted;

  /// True when the OS will no longer show a prompt and only Settings can help.
  bool get requiresSettings =>
      permission == NotificationPermissionStatus.permanentlyDenied;

  PushRegistrationState copyWith({
    NotificationPermissionStatus? permission,
    bool? registered,
    String? deviceId,
    bool? isSupported,
    bool? busy,
    String? error,
    bool clearError = false,
  }) {
    return PushRegistrationState(
      permission: permission ?? this.permission,
      registered: registered ?? this.registered,
      deviceId: deviceId ?? this.deviceId,
      isSupported: isSupported ?? this.isSupported,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PushRegistrationState &&
      other.permission == permission &&
      other.registered == registered &&
      other.deviceId == deviceId &&
      other.isSupported == isSupported &&
      other.busy == busy &&
      other.error == error;

  @override
  int get hashCode =>
      Object.hash(permission, registered, deviceId, isSupported, busy, error);
}

/// Describes this install to the backend when registering a device.
class DeviceDescriptor {
  const DeviceDescriptor({this.deviceName, this.appVersion});
  final String? deviceName;
  final String? appVersion;
}

/// Owns the FCM token lifecycle for the signed-in user.
///
/// Responsibilities:
///  * ask for permission at most once,
///  * fetch the token and register it with FastAPI,
///  * re-register whenever FCM rotates the token,
///  * stay silent (never throw) when push is unavailable or declined.
class DeviceRegistrationController {
  DeviceRegistrationController({
    required FcmService fcm,
    required Future<String> Function({
      required String fcmToken,
      required String platform,
      String? deviceName,
      String? appVersion,
    })
    register,
    required this.descriptor,
    NotificationPermissionStore? permissionStore,
  }) : _fcm = fcm,
       _register = register,
       _permissionStore =
           permissionStore ?? InMemoryNotificationPermissionStore();

  final FcmService _fcm;
  final Future<String> Function({
    required String fcmToken,
    required String platform,
    String? deviceName,
    String? appVersion,
  })
  _register;
  final NotificationPermissionStore _permissionStore;
  final DeviceDescriptor descriptor;

  StreamSubscription<String>? _tokenSubscription;
  PushRegistrationState _state = const PushRegistrationState();
  bool _started = false;

  PushRegistrationState get state => _state;

  void _emit(PushRegistrationState next) {
    _state = next;
  }

  /// Registers this device and begins watching for token rotation.
  ///
  /// Returns the resulting state instead of throwing: a failure here must
  /// never prevent the user reaching the app.
  Future<PushRegistrationState> start() async {
    if (_started) return _state;
    _started = true;

    if (!_fcm.isSupported) {
      _emit(const PushRegistrationState(isSupported: false));
      return _state;
    }

    _emit(_state.copyWith(isSupported: true, busy: true, clearError: true));

    // "Have we already asked?" is what turns a bare denial into a permanent
    // one, so it has to be read before the status is resolved.
    final askedBefore = await _permissionStore.wasAsked();

    var permission = await _fcm.checkPermission(askedBefore: askedBefore);
    if (permission == NotificationPermissionStatus.undetermined &&
        !askedBefore) {
      // The very first prompt. A refusal here is reported as plain `denied`
      // rather than permanent, so the UI does not send the user to Settings on
      // a first refusal.
      await _permissionStore.markAsked();
      permission = await _fcm.requestPermission();
    }
    _emit(_state.copyWith(permission: permission));

    if (permission != NotificationPermissionStatus.granted) {
      // Declined or blocked: the app stays fully usable, we just never push.
      _emit(_state.copyWith(busy: false, registered: false));
      return _state;
    }

    await _registerCurrentToken();

    // FCM tokens are rotated by the OS; re-register on every change or push
    // delivery silently stops.
    _tokenSubscription = _fcm.onTokenRefresh().listen((token) {
      if (token.isEmpty) return;
      unawaited(_registerToken(token));
    });

    return _state;
  }

  Future<void> _registerCurrentToken() async {
    final token = await _fcm.getToken();
    if (token == null || token.isEmpty) {
      _emit(_state.copyWith(busy: false));
      return;
    }
    await _registerToken(token);
  }

  Future<void> _registerToken(String token) async {
    try {
      final deviceId = await _register(
        fcmToken: token,
        platform: _platformValue,
        deviceName: descriptor.deviceName,
        appVersion: descriptor.appVersion,
      );
      _emit(
        _state.copyWith(
          registered: true,
          deviceId: deviceId,
          busy: false,
          clearError: true,
        ),
      );
    } catch (error) {
      // Never surface a raw backend/socket error to the user; push is optional.
      debugPrint('Device registration failed: ${error.runtimeType}');
      _emit(_state.copyWith(registered: false, busy: false));
    }
  }

  String get _platformValue {
    if (kIsWeb) return 'WEB';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'IOS';
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return 'ANDROID';
    }
  }

  /// Opens the OS notification settings, for the permanently-denied state.
  ///
  /// Re-requesting cannot succeed once the OS has stopped prompting, so the
  /// only recovery path is the system Settings screen. FCM exposes no API for
  /// this, so it is the caller's job (see the notification settings screen).
  bool get requiresSystemSettings => _state.requiresSettings;

  /// Re-checks the OS permission, e.g. after returning from system Settings.
  Future<PushRegistrationState> recheckPermission() async {
    if (!_state.isSupported) return _state;
    final askedBefore = await _permissionStore.wasAsked();
    final permission = await _fcm.checkPermission(askedBefore: askedBefore);
    _emit(_state.copyWith(permission: permission));
    if (permission == NotificationPermissionStatus.granted) {
      await _registerCurrentToken();
    }
    return _state;
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
    _started = false;
  }
}
