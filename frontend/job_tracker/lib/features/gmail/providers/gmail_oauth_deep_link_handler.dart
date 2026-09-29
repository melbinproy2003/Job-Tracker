import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_router.dart';
import '../../../app/router/route_names.dart';
import '../../../core/constants/scaffold_messenger_key.dart';
import '../domain/gmail_oauth_deep_link.dart';
import 'gmail_providers.dart';

/// Listens for `jobtracker://gmail/...` OAuth returns via [AppLinks].
///
/// Covers cold start (`getInitialLink`), background resume, and foreground
/// delivery. Always refreshes account state from FastAPI — never trusts the
/// deep link as proof of credentials.
class GmailOAuthDeepLinkHandler {
  GmailOAuthDeepLinkHandler({required Ref ref, AppLinks? appLinks})
    : _ref = ref,
      _appLinks = appLinks ?? AppLinks();

  final Ref _ref;
  final AppLinks _appLinks;

  StreamSubscription<Uri>? _subscription;
  String? _lastHandledKey;
  DateTime? _lastHandledAt;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        await _handle(initial, source: 'initial');
      }
    } catch (error) {
      debugPrint('Gmail OAuth initial link failed: ${error.runtimeType}');
    }

    _subscription = _appLinks.uriLinkStream.listen(
      (uri) {
        unawaited(_handle(uri, source: 'stream'));
      },
      onError: (Object error) {
        debugPrint('Gmail OAuth link stream error: ${error.runtimeType}');
      },
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
  }

  /// Test seam: process a URI without AppLinks.
  @visibleForTesting
  Future<void> handleForTest(Uri uri) => _handle(uri, source: 'test');

  Future<void> _handle(Uri uri, {required String source}) async {
    if (GmailOAuthDeepLink.containsForbiddenCredentialParams(uri)) {
      debugPrint('Rejected Gmail OAuth deep link with credential-like params');
      return;
    }

    final parsed = GmailOAuthDeepLink.tryParse(uri);
    if (parsed == null) return;

    // OAuth returns can fire both as initial + stream; debounce duplicates.
    final key = '${parsed.kind.name}:${uri.path}';
    final now = DateTime.now();
    if (_lastHandledKey == key &&
        _lastHandledAt != null &&
        now.difference(_lastHandledAt!) < const Duration(seconds: 4)) {
      return;
    }
    _lastHandledKey = key;
    _lastHandledAt = now;

    debugPrint('Gmail OAuth deep link ($source): ${parsed.kind.name}');
    if (!parsed.isSuccess) {
      // Log only the sanitized code — never raw OAuth payloads.
      debugPrint('Gmail OAuth error code: ${parsed.errorCode}');
    }

    // Backend already stored credentials during /callback. Refresh the UI.
    _ref.invalidate(gmailAccountsProvider);
    _ref.invalidate(gmailAccountProvider);
    _ref.invalidate(isGmailConnectedProvider);
    _ref.invalidate(gmailThreadsProvider(null));

    try {
      final router = _ref.read(appRouterProvider);
      router.go(RouteNames.settingsEmail);
    } catch (error) {
      debugPrint('Gmail OAuth navigate failed: ${error.runtimeType}');
    }

    await Future<void>.delayed(const Duration(milliseconds: 100));
    try {
      await _ref.read(gmailAccountsProvider.future);
    } catch (_) {
      // Settings screen will surface load errors.
    }

    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(parsed.userMessage),
        action: parsed.isSuccess
            ? null
            : SnackBarAction(
                label: 'Try Again',
                onPressed: () {
                  _ref.read(appRouterProvider).go(RouteNames.settingsEmail);
                },
              ),
      ),
    );
  }
}

final gmailOAuthDeepLinkHandlerProvider = Provider<GmailOAuthDeepLinkHandler>((
  ref,
) {
  final handler = GmailOAuthDeepLinkHandler(ref: ref);
  ref.onDispose(() {
    unawaited(handler.dispose());
  });
  return handler;
});

/// Starts the deep-link listener once per session (open / background / cold).
final gmailOAuthDeepLinkBootstrapProvider = FutureProvider<void>((ref) async {
  await ref.read(gmailOAuthDeepLinkHandlerProvider).start();
});
