import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/notifications/notification_router_core.dart';
import '../../../notifications/providers/notifications_providers.dart';

/// Authenticated bottom navigation shell.
///
/// Also the app-wide host for two notification concerns, because the shell is
/// the one widget that exists for the whole signed-in session:
///  * navigation to whatever a tapped notification points at;
///  * the in-app banner for a push that arrives while the user is looking at
///    the app (the OS stays silent in the foreground).
class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  @override
  Widget build(BuildContext context) {
    // A tap may resolve from the tray or from a locally drawn notification.
    ref.listen<AsyncValue<NotificationDestination>>(notificationTapProvider, (
      _,
      next,
    ) {
      final destination = next.valueOrNull;
      if (destination == null) return;
      final uri = destination.queryParameters.isEmpty
          ? destination.routePath
          : Uri(
              path: destination.routePath,
              queryParameters: destination.queryParameters,
            ).toString();
      context.go(uri);
    });

    return Scaffold(
      body: Stack(
        children: [
          widget.navigationShell,
          const _ForegroundNotificationBanner(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: (index) {
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.work_outline),
            selectedIcon: Icon(Icons.work),
            label: 'Apps',
          ),
          NavigationDestination(
            icon: Icon(Icons.business_outlined),
            selectedIcon: Icon(Icons.business),
            label: 'Companies',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Interviews',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Follow-ups',
          ),
        ],
      ),
    );
  }
}

/// Transient banner for a foreground push.
///
/// Tapping it routes exactly as a system-tray tap would, because it feeds the
/// same payload through the same [NotificationRouter]. Delivery alone never
/// navigates — the user has to tap.
class _ForegroundNotificationBanner extends ConsumerStatefulWidget {
  const _ForegroundNotificationBanner();

  @override
  ConsumerState<_ForegroundNotificationBanner> createState() =>
      _ForegroundNotificationBannerState();
}

class _ForegroundNotificationBannerState
    extends ConsumerState<_ForegroundNotificationBanner> {
  static const _visibleFor = Duration(seconds: 6);

  Map<String, dynamic>? _payload;
  String _title = '';
  String _body = '';
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<Map<String, dynamic>>>(
      foregroundNotificationProvider,
      (_, next) {
        final data = next.valueOrNull;
        if (data == null || !mounted) return;
        setState(() {
          _payload = data;
          _title = _titleOf(data);
          _body = _bodyOf(data);
          _visible = true;
        });
        Future.delayed(_visibleFor, () {
          if (mounted) setState(() => _visible = false);
        });
      },
    );
  }

  /// FCM puts display text in `notification`, but data-only sends carry
  /// `title`/`body` instead, so both are checked.
  static String _titleOf(Map<String, dynamic> data) =>
      data['title']?.toString().trim() ?? '';

  static String _bodyOf(Map<String, dynamic> data) =>
      data['body']?.toString().trim() ?? '';

  void _open() {
    final payload = _payload;
    if (payload == null) return;
    setState(() => _visible = false);
    // Route through the handler so the banner and the tray share one path.
    ref.read(notificationHandlerProvider).handleExternalPayload(payload);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible || _title.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12,
      right: 12,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.inverseSurface,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _open,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_active,
                  size: 20,
                  color: theme.colorScheme.onInverseSurface,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onInverseSurface,
                        ),
                      ),
                      if (_body.isNotEmpty)
                        Text(
                          _body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onInverseSurface
                                .withValues(alpha: 0.8),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: theme.colorScheme.onInverseSurface,
                  ),
                  onPressed: () => setState(() => _visible = false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
