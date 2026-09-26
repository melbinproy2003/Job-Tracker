import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/notifications/notification_router_core.dart';
import '../../../../shared/empty_states/empty_view.dart';
import '../../../../shared/error/error_view.dart';
import '../../../../shared/loading/loading_view.dart';
import '../../domain/entities/app_notification.dart';
import '../../providers/notifications_providers.dart';
import '../controllers/notification_actions.dart';
import '../widgets/notification_card.dart';

/// The in-app notification centre (Phase 4).
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(notificationGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;
              if (unread == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: () =>
                    ref.read(notificationActionsProvider).markAllRead(),
                child: const Text('Mark all read'),
              );
            },
          ),
        ],
      ),
      body: groups.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: 'Could not load notifications.',
          onRetry: () => ref.invalidate(notificationListProvider),
        ),
        data: (data) {
          if (data.isEmpty) {
            return const EmptyView(
              title: 'No notifications',
              message: 'Reminders and job emails will appear here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(notificationListProvider),
            child: ListView(
              children: [
                if (data.today.isNotEmpty) ...[
                  _SectionHeader('Today', data.today),
                  ...data.today.map((n) => _tile(context, ref, n)),
                ],
                if (data.yesterday.isNotEmpty) ...[
                  _SectionHeader('Yesterday', data.yesterday),
                  ...data.yesterday.map((n) => _tile(context, ref, n)),
                ],
                if (data.earlier.isNotEmpty) ...[
                  _SectionHeader('Earlier', data.earlier),
                  ...data.earlier.map((n) => _tile(context, ref, n)),
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, WidgetRef ref, AppNotification item) {
    return NotificationCard(
      notification: item,
      onTap: () {
        final actions = ref.read(notificationActionsProvider);
        if (!item.read) actions.markRead(item.id);
        _openDestination(context, item);
      },
      onDismissed: () => ref.read(notificationActionsProvider).delete(item.id),
    );
  }

  /// Reuses the same routing rules as a push tap so a notification navigates
  /// identically whether it was tapped in the tray or in the list.
  void _openDestination(BuildContext context, AppNotification item) {
    final destination = const NotificationRouter().resolve(item.toPayload());
    if (destination == null) return;
    // `context.go` takes a location, not separate query parameters, so the
    // destination is folded back into a single URI.
    final uri = destination.queryParameters.isEmpty
        ? destination.routePath
        : Uri(
            path: destination.routePath,
            queryParameters: destination.queryParameters,
          ).toString();
    context.go(uri);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label, this.items);

  final String label;
  final List<AppNotification> items;

  @override
  Widget build(BuildContext context) {
    final unread = items.where((n) => !n.read).length;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (unread > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$unread',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
