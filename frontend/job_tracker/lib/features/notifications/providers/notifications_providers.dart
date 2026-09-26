import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/notifications/fcm_service.dart';
import '../../../core/notifications/notification_handler.dart';
import '../../../core/notifications/notification_router_core.dart';
import '../../../core/notifications/notification_service.dart';
import '../../authentication/presentation/controllers/auth_controller.dart';
import '../../authentication/providers/auth_providers.dart';
import '../data/datasources/notifications_remote_datasource.dart';
import '../data/repositories/notifications_repository_impl.dart';
import '../domain/entities/app_notification.dart';
import '../domain/repositories/notifications_repository.dart';
import '../domain/services/device_registration_controller.dart';

final notificationsRemoteDataSourceProvider =
    Provider<NotificationsRemoteDataSource>((ref) {
      return NotificationsRemoteDataSource(ref.watch(dioProvider));
    });

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepositoryImpl(
    ref.watch(notificationsRemoteDataSourceProvider),
  );
});

/// Unread badge count, polled by the app bar.
final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  return ref.watch(notificationRepositoryProvider).unreadCount();
});

/// The full notification inbox, newest first.
final notificationListProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
      return ref.watch(notificationRepositoryProvider).getAll();
    });

final notificationPreferencesProvider =
    FutureProvider.autoDispose<NotificationPreferences>((ref) async {
      return ref.watch(notificationRepositoryProvider).getPreferences();
    });

/// Push registration state for this install.
final pushRegistrationProvider =
    NotifierProvider<PushRegistrationNotifier, PushRegistrationState>(
      PushRegistrationNotifier.new,
    );

final fcmServiceProvider = Provider<FcmService>((ref) => FcmService());

/// Local key/value storage for non-credential preferences.
///
/// Reused for the notification permission prompt flag so that "do not ask
/// again" survives a restart without pulling in another package.
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
});

/// Persisted "have we already prompted for notifications?" flag.
final notificationPermissionStoreProvider =
    Provider<NotificationPermissionStore>((ref) {
      return SecureNotificationPermissionStore(
        ref.watch(secureStorageProvider),
      );
    });

/// Bridges Riverpod to the FCM lifecycle without owning a `StateNotifier` per
/// token refresh.
class PushRegistrationNotifier extends Notifier<PushRegistrationState> {
  @override
  PushRegistrationState build() {
    ref.onDispose(() {
      _disposed = true;
      _controller?.dispose();
    });
    return const PushRegistrationState();
  }

  DeviceRegistrationController? _controller;

  /// Riverpod 2.x's [Notifier] ref has no `mounted` flag, so disposal is
  /// tracked here to avoid writing state after the container is gone.
  bool _disposed = false;

  /// Starts registration once the user is authenticated.
  Future<void> ensureRegistered() async {
    if (_controller != null || _disposed) return;
    final repository = ref.read(notificationRepositoryProvider);
    final controller = DeviceRegistrationController(
      fcm: ref.read(fcmServiceProvider),
      register:
          ({
            required String fcmToken,
            required String platform,
            String? deviceName,
            String? appVersion,
          }) => repository.registerDevice(
            fcmToken: fcmToken,
            platform: platform,
            deviceName: deviceName,
            appVersion: appVersion,
          ),
      descriptor: const DeviceDescriptor(
        appVersion: String.fromEnvironment(
          'APP_VERSION',
          defaultValue: '1.0.0',
        ),
      ),
      permissionStore: ref.read(notificationPermissionStoreProvider),
    );
    _controller = controller;
    final next = await controller.start();
    if (_disposed) return;
    state = next;
  }

  /// Re-reads the OS permission, e.g. after the user returns from Settings.
  Future<void> refreshPermission() async {
    final controller = _controller;
    if (controller == null || _disposed) return;
    final next = await controller.recheckPermission();
    if (_disposed) return;
    state = next;
  }

  /// True when the OS has stopped prompting and only Settings can help.
  bool get needsSystemSettings => state.requiresSettings;
}

final notificationHandlerProvider = Provider<NotificationHandler>((ref) {
  final handler = NotificationHandler();
  ref.onDispose(() => handler.dispose());
  return handler;
});

/// Local (in-app drawn) notifications, for foreground and data-only pushes.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Foreground pushes, surfaced as a banner in the app shell.
///
/// Deliberately the only foreground presentation: the OS stays silent while the
/// app is visible, so a banner is enough and adding a tray notification on top
/// would be noise. The tray is reserved for messages that arrive in the
/// background isolate, which no banner could cover.
final foregroundNotificationProvider = StreamProvider<Map<String, dynamic>>(
  (ref) => ref.watch(notificationHandlerProvider).onForegroundMessage,
);

/// Destinations produced by tapping a notification.
final notificationTapProvider = StreamProvider<NotificationDestination>((ref) {
  return ref.watch(notificationHandlerProvider).onNotificationTap;
});

/// Adapts [FcmService] to the seam expected by `NotificationHandler`.
class LiveFcmAdapter implements FcmServiceAdapter {
  LiveFcmAdapter(this._service);
  final FcmService _service;

  @override
  bool get presentedInForeground => true;

  @override
  Future<void> initialize() => _service.initialize();

  @override
  Stream<String> onTokenRefresh() => _service.onTokenRefresh();

  @override
  Stream<RemoteMessage> onForegroundMessage() => _service.onForegroundMessage();

  @override
  Future<RemoteMessage?> initialMessage() => FcmService.getInitialMessage();
}

/// Starts the FCM pipeline once, at app level.
///
/// Two independent concerns are kicked off here:
///  * the [NotificationHandler] streams, which must be live before the first
///    frame so a tap that opened the app is not lost;
///  * device registration with the backend, which requires an authenticated
///    user and therefore happens only once auth resolves.
final notificationBootstrapProvider = FutureProvider<void>((ref) async {
  final handler = ref.watch(notificationHandlerProvider);
  final service = ref.watch(fcmServiceProvider);
  await handler.initialize(adapter: LiveFcmAdapter(service));

  // Register the device as soon as there is a signed-in user. Unauthenticated
  // calls would be rejected by the backend, so this is deliberately gated
  // rather than fired at startup.
  ref.listen<AuthenticationState>(authControllerProvider, (_, next) {
    if (!next.isAuthenticated) return;
    ref.read(pushRegistrationProvider.notifier).ensureRegistered();
  });

  // A user already signed in when the app cold-started.
  if (ref.read(authControllerProvider).isAuthenticated) {
    await ref.read(pushRegistrationProvider.notifier).ensureRegistered();
  }

  debugPrint('Notification pipeline ready');
});
