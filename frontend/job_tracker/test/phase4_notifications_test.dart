import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_tracker/core/enums/notification_type.dart';
import 'package:job_tracker/core/notifications/fcm_service.dart';
import 'package:job_tracker/core/notifications/notification_handler.dart';
import 'package:job_tracker/core/notifications/notification_router_core.dart';
import 'package:job_tracker/features/notifications/domain/entities/app_notification.dart';
import 'package:job_tracker/features/notifications/domain/services/device_registration_controller.dart';

/// Records what was registered and lets a test drive the token stream.
class _FakeFcm implements FcmService {
  _FakeFcm({
    this.authorization = AuthorizationStatus.authorized,
    this.afterRequest,
    this.supported = true,
  });

  /// The raw OS status. The mapping to the app's own enum goes through the
  /// real [FcmService.fromAuthorizationStatus] so the controller is tested
  /// against production behaviour rather than a re-implementation.
  AuthorizationStatus authorization;

  /// What the OS reports once the user has answered the prompt. Models the
  /// real transition from `notDetermined` to the user's choice.
  final AuthorizationStatus? afterRequest;

  String? token = 'token-1';
  bool supported;

  final _tokenController = StreamController<String>.broadcast();
  final _messageController = StreamController<RemoteMessage>.broadcast();

  int initializeCalls = 0;
  int requestCalls = 0;
  int checkCalls = 0;
  int registerCalls = 0;
  String? lastPlatform;
  String? lastToken;

  @override
  bool get isSupported => supported;

  @override
  Future<void> initialize() async => initializeCalls++;

  @override
  Future<NotificationPermissionStatus> requestPermission({
    bool askedBefore = false,
  }) async {
    requestCalls++;
    if (afterRequest != null) authorization = afterRequest!;
    return FcmService.fromAuthorizationStatus(
      authorization,
      askedBefore: askedBefore,
    );
  }

  @override
  Future<NotificationPermissionStatus> checkPermission({
    bool askedBefore = false,
  }) async {
    checkCalls++;
    return FcmService.fromAuthorizationStatus(
      authorization,
      askedBefore: askedBefore,
    );
  }

  @override
  Future<String?> getToken() async => token;

  @override
  Stream<String> onTokenRefresh() => _tokenController.stream;

  @override
  Stream<RemoteMessage> onForegroundMessage() => _messageController.stream;

  void emitToken(String value) => _tokenController.add(value);

  void emitMessage(
    Map<String, dynamic> data, {
    String? notificationTitle,
    String? notificationBody,
  }) => _messageController.add(
    RemoteMessage(
      messageId: 'm1',
      data: data,
      notification: (notificationTitle != null || notificationBody != null)
          ? RemoteNotification(title: notificationTitle, body: notificationBody)
          : null,
    ),
  );

  Future<void> close() async {
    await _tokenController.close();
    await _messageController.close();
  }
}

/// A store that records whether the flag was written, standing in for
/// `flutter_secure_storage`.
class _RecordingPermissionStore implements NotificationPermissionStore {
  _RecordingPermissionStore({this.asked = false});

  bool asked;
  int markAskedCalls = 0;

  @override
  Future<bool> wasAsked() async => asked;

  @override
  Future<void> markAsked() async {
    asked = true;
    markAskedCalls++;
  }
}

DeviceRegistrationController _controller({
  required _FakeFcm fcm,
  NotificationPermissionStore? store,
}) {
  return DeviceRegistrationController(
    fcm: fcm,
    register:
        ({
          required String fcmToken,
          required String platform,
          String? deviceName,
          String? appVersion,
        }) async {
          fcm.registerCalls++;
          fcm.lastToken = fcmToken;
          fcm.lastPlatform = platform;
          return 'device-1';
        },
    descriptor: const DeviceDescriptor(appVersion: '1.0.0'),
    permissionStore: store ?? _RecordingPermissionStore(),
  );
}

void main() {
  group('NotificationRouter', () {
    const router = NotificationRouter();

    test('returns null for an empty payload', () {
      expect(router.resolve(const {}), isNull);
    });

    test('routes an interview reminder to the interview detail', () {
      final destination = router.resolve({
        'type': 'INTERVIEW_REMINDER',
        'notification_id': 'n1',
        'interview_id': 'iv1',
        'application_id': 'app1',
      });
      expect(destination, isNotNull);
      expect(destination!.routePath, '/interviews/iv1');
      expect(destination.queryParameters, {'applicationId': 'app1'});
    });

    test('falls back to the interview list without an application', () {
      final destination = router.resolve({'interview_id': 'iv1'});
      expect(destination!.routePath, '/interviews');
    });

    test('routes a follow-up through its application with a focus hint', () {
      final destination = router.resolve({
        'followup_id': 'f1',
        'application_id': 'app1',
      });
      expect(destination!.routePath, '/applications/app1');
      expect(destination.queryParameters, {'focusFollowupId': 'f1'});
    });

    test('routes a Gmail push using the backend thread_id key', () {
      // The backend writes `thread_id`, not `gmail_thread_id`; using the
      // wrong key here would silently land on the notification hub.
      final destination = router.resolve({
        'type': 'GMAIL_EMAIL_DETECTED',
        'thread_id': 't1',
      });
      expect(destination!.routePath, '/gmail/threads/t1');
    });

    test('prefers the message detail over the thread', () {
      final destination = router.resolve({
        'thread_id': 't1',
        'gmail_message_id': 'm1',
      });
      expect(destination!.routePath, '/gmail/messages/m1');
    });

    test('falls back to the notification hub when nothing is addressable', () {
      final destination = router.resolve({'type': 'SYSTEM'});
      expect(destination!.routePath, '/notifications');
    });

    test('treats blank ids as absent', () {
      final destination = router.resolve({
        'application_id': '   ',
        'interview_id': '',
      });
      expect(destination!.routePath, '/notifications');
    });
  });

  group('AppNotification.toPayload', () {
    test('reproduces the backend push contract', () {
      final notification = AppNotification(
        id: 'n1',
        type: AppNotificationType.interviewReminder,
        title: 'Interview tomorrow',
        body: 'Acme at 10:00',
        data: const {'reminder_type': '24h'},
        relatedApplicationId: 'app1',
        relatedInterviewId: 'iv1',
        createdAt: DateTime.utc(2026, 1, 1),
      );

      final payload = notification.toPayload();
      expect(payload['type'], 'INTERVIEW_REMINDER');
      expect(payload['notification_id'], 'n1');
      expect(payload['reminder_type'], '24h');
      expect(payload['application_id'], 'app1');
      expect(payload['interview_id'], 'iv1');
      expect(payload.containsKey('followup_id'), isFalse);
    });

    test('omits absent ids so the router can fall back', () {
      final notification = AppNotification(
        id: 'n2',
        type: AppNotificationType.system,
        title: 'Hi',
        body: '',
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final payload = notification.toPayload();
      expect(payload.containsKey('application_id'), isFalse);
      expect(payload.containsKey('interview_id'), isFalse);
      expect(payload.containsKey('followup_id'), isFalse);
    });
  });

  group('FcmService.fromAuthorizationStatus', () {
    test('maps authorized and provisional to granted', () {
      expect(
        FcmService.fromAuthorizationStatus(AuthorizationStatus.authorized),
        NotificationPermissionStatus.granted,
      );
      expect(
        FcmService.fromAuthorizationStatus(AuthorizationStatus.provisional),
        NotificationPermissionStatus.granted,
      );
    });

    test('maps notDetermined to undetermined', () {
      expect(
        FcmService.fromAuthorizationStatus(AuthorizationStatus.notDetermined),
        NotificationPermissionStatus.undetermined,
      );
    });

    test('a first denial stays re-askable', () {
      expect(
        FcmService.fromAuthorizationStatus(AuthorizationStatus.denied),
        NotificationPermissionStatus.denied,
      );
    });

    test('a denial after an earlier prompt is permanent', () {
      // iOS/Android stop prompting after repeated refusals, so only Settings
      // can recover; the UI must be able to tell the user that.
      expect(
        FcmService.fromAuthorizationStatus(
          AuthorizationStatus.denied,
          askedBefore: true,
        ),
        NotificationPermissionStatus.permanentlyDenied,
      );
    });
  });

  group('DeviceRegistrationController', () {
    test('registers when permission is already granted', () async {
      final fcm = _FakeFcm();
      final controller = _controller(fcm: fcm);

      final state = await controller.start();

      expect(state.registered, isTrue);
      expect(fcm.registerCalls, 1);
      expect(fcm.requestCalls, 0, reason: 'must not re-ask');
      await controller.dispose();
      await fcm.close();
    });

    test('prompts exactly once on first run and persists that', () async {
      // First launch: the OS has not asked yet, and the user says no.
      final fcm = _FakeFcm(
        authorization: AuthorizationStatus.notDetermined,
        afterRequest: AuthorizationStatus.denied,
      );
      final store = _RecordingPermissionStore();
      final controller = _controller(fcm: fcm, store: store);

      final state = await controller.start();

      expect(fcm.requestCalls, 1);
      expect(store.markAskedCalls, 1);
      expect(state.registered, isFalse);
      await controller.dispose();
      await fcm.close();
    });

    test('never prompts again on a later launch', () async {
      final fcm = _FakeFcm(authorization: AuthorizationStatus.denied);
      // The flag survived, so the store reports a previous prompt.
      final store = _RecordingPermissionStore(asked: true);
      final controller = _controller(fcm: fcm, store: store);

      final state = await controller.start();

      expect(fcm.requestCalls, 0, reason: 'Play Store penalises re-prompting');
      expect(
        state.permission,
        NotificationPermissionStatus.permanentlyDenied,
        reason: 'a refusal after a prompt can only be fixed in Settings',
      );
      expect(state.requiresSettings, isTrue);
      await controller.dispose();
      await fcm.close();
    });

    test('re-registers when FCM rotates the token', () async {
      final fcm = _FakeFcm();
      final controller = _controller(fcm: fcm);

      await controller.start();
      expect(fcm.registerCalls, 1);

      fcm.emitToken('token-2');
      await Future<void>.delayed(Duration.zero);

      expect(fcm.registerCalls, 2, reason: 'push stops without re-register');
      await controller.dispose();
      await fcm.close();
    });

    test('stays usable on an unsupported platform', () async {
      final fcm = _FakeFcm(supported: false);
      final controller = _controller(fcm: fcm);

      final state = await controller.start();

      expect(state.isSupported, isFalse);
      expect(state.registered, isFalse);
      expect(fcm.registerCalls, 0);
      await controller.dispose();
      await fcm.close();
    });

    test('survives a failing registration without throwing', () async {
      final fcm = _FakeFcm();
      final controller = DeviceRegistrationController(
        fcm: fcm,
        register:
            ({
              required String fcmToken,
              required String platform,
              String? deviceName,
              String? appVersion,
            }) async => throw Exception('offline'),
        descriptor: const DeviceDescriptor(),
        permissionStore: _RecordingPermissionStore(),
      );

      final state = await controller.start();

      expect(state.registered, isFalse);
      expect(state.busy, isFalse);
      await controller.dispose();
      await fcm.close();
    });
  });

  group('NotificationHandler', () {
    test('publishes a foreground payload without navigating', () async {
      final handler = NotificationHandler();
      final foreground = <Map<String, dynamic>>[];
      final taps = <NotificationDestination>[];
      final sub = handler.onForegroundMessage.listen(foreground.add);
      final tapSub = handler.onNotificationTap.listen(taps.add);

      final fcm = _FakeFcm();
      await handler.initialize(adapter: _adapter(fcm));
      fcm.emitMessage({'type': 'INTERVIEW_REMINDER', 'interview_id': 'iv1'});
      await Future<void>.delayed(Duration.zero);

      expect(foreground, hasLength(1));
      expect(
        taps,
        isEmpty,
        reason: 'receiving a push must never move the user',
      );

      await sub.cancel();
      await tapSub.cancel();
      await handler.dispose();
      await fcm.close();
    });

    test('merges display text from the FCM notification block', () async {
      // The backend sends routing keys in `data` and the title/body in a
      // separate `notification` block. Without merging, the banner has no
      // title to render and the shell hides it entirely.
      final handler = NotificationHandler();
      final foreground = <Map<String, dynamic>>[];
      final sub = handler.onForegroundMessage.listen(foreground.add);
      final fcm = _FakeFcm();
      await handler.initialize(adapter: _adapter(fcm));

      fcm.emitMessage(
        {'type': 'INTERVIEW_REMINDER', 'interview_id': 'iv1'},
        notificationTitle: 'Interview tomorrow',
        notificationBody: 'Acme at 10:00',
      );
      await Future<void>.delayed(Duration.zero);

      expect(foreground, hasLength(1));
      expect(foreground.single['title'], 'Interview tomorrow');
      expect(foreground.single['body'], 'Acme at 10:00');
      expect(foreground.single['interview_id'], 'iv1');

      await sub.cancel();
      await handler.dispose();
      await fcm.close();
    });

    test('explicit data title wins over the notification block', () async {
      final handler = NotificationHandler();
      final foreground = <Map<String, dynamic>>[];
      final sub = handler.onForegroundMessage.listen(foreground.add);
      final fcm = _FakeFcm();
      await handler.initialize(adapter: _adapter(fcm));

      fcm.emitMessage(
        {'title': 'Data title', 'body': 'Data body'},
        notificationTitle: 'Block title',
        notificationBody: 'Block body',
      );
      await Future<void>.delayed(Duration.zero);

      expect(foreground.single['title'], 'Data title');
      expect(foreground.single['body'], 'Data body');

      await sub.cancel();
      await handler.dispose();
      await fcm.close();
    });

    test('shows a notification-only message with no data', () async {
      final handler = NotificationHandler();
      final foreground = <Map<String, dynamic>>[];
      final sub = handler.onForegroundMessage.listen(foreground.add);
      final fcm = _FakeFcm();
      await handler.initialize(adapter: _adapter(fcm));

      fcm.emitMessage(
        const {},
        notificationTitle: 'Just so you know',
        notificationBody: 'Body',
      );
      await Future<void>.delayed(Duration.zero);

      expect(foreground, hasLength(1));
      expect(foreground.single['title'], 'Just so you know');

      await sub.cancel();
      await handler.dispose();
      await fcm.close();
    });

    test('routes an explicitly tapped payload', () async {
      final handler = NotificationHandler();
      final taps = <NotificationDestination>[];
      final tapSub = handler.onNotificationTap.listen(taps.add);
      await handler.initialize(adapter: _adapter(_FakeFcm()));

      handler.handleExternalPayload({
        'type': 'GMAIL_EMAIL_DETECTED',
        'thread_id': 't9',
      });
      await Future<void>.delayed(Duration.zero);

      expect(taps, hasLength(1));
      expect(taps.single.routePath, '/gmail/threads/t9');

      await tapSub.cancel();
      await handler.dispose();
    });
  });
}

FcmServiceAdapter _adapter(_FakeFcm fcm, {RemoteMessage? initial}) =>
    _FakeFcmAdapter(fcm, initial);

class _FakeFcmAdapter implements FcmServiceAdapter {
  _FakeFcmAdapter(this._fcm, this._initial);
  final _FakeFcm _fcm;

  /// Stands in for the message a cold start from a tap would deliver.
  final RemoteMessage? _initial;

  @override
  bool get presentedInForeground => true;

  @override
  Future<void> initialize() => _fcm.initialize();

  @override
  Stream<String> onTokenRefresh() => _fcm.onTokenRefresh();

  @override
  Stream<RemoteMessage> onForegroundMessage() => _fcm.onForegroundMessage();

  @override
  Future<RemoteMessage?> initialMessage() async => _initial;
}
