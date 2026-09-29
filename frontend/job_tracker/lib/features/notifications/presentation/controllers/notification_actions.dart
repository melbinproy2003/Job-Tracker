import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_notification.dart';
import '../../providers/notifications_providers.dart';

/// Notifications bucketed by day for the sectioned inbox.
class NotificationGroups extends Equatable {
  const NotificationGroups({
    this.today = const [],
    this.yesterday = const [],
    this.earlier = const [],
  });

  final List<AppNotification> today;
  final List<AppNotification> yesterday;
  final List<AppNotification> earlier;

  bool get isEmpty => today.isEmpty && yesterday.isEmpty && earlier.isEmpty;

  int get total => today.length + yesterday.length + earlier.length;

  int get unreadTotal =>
      today.where((n) => !n.read).length +
      yesterday.where((n) => !n.read).length +
      earlier.where((n) => !n.read).length;

  @override
  List<Object?> get props => [today, yesterday, earlier];
}

/// Splits a newest-first list into Today / Yesterday / Earlier.
///
/// Pure and injectable-clock so the grouping is unit testable without pumping
/// widgets or waiting for midnight.
NotificationGroups groupNotifications(
  List<AppNotification> items, {
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final todayStart = DateTime(reference.year, reference.month, reference.day);
  final yesterdayStart = todayStart.subtract(const Duration(days: 1));

  final today = <AppNotification>[];
  final yesterday = <AppNotification>[];
  final earlier = <AppNotification>[];

  for (final item in items) {
    final at = item.createdAt ?? item.sentAt;
    if (at == null) {
      earlier.add(item);
      continue;
    }
    if (!at.isBefore(todayStart)) {
      today.add(item);
    } else if (!at.isBefore(yesterdayStart)) {
      yesterday.add(item);
    } else {
      earlier.add(item);
    }
  }

  return NotificationGroups(
    today: today,
    yesterday: yesterday,
    earlier: earlier,
  );
}

final notificationGroupsProvider =
    Provider.autoDispose<AsyncValue<NotificationGroups>>((ref) {
      final list = ref.watch(notificationListProvider);
      return list.whenData((items) => groupNotifications(items));
    });

/// Mutations for the notification centre.
///
/// Optimistic updates are deliberately avoided for read-state: a mark-read that
/// the server rejects would leave the UI lying, and the inbox is cheap to
/// refetch. Instead each action invalidates the relevant queries.
class NotificationActions {
  const NotificationActions(this._ref);
  final Ref _ref;

  Future<void> markRead(String id) async {
    await _ref.read(notificationRepositoryProvider).markRead(id);
    _invalidate();
  }

  Future<void> markAllRead() async {
    await _ref.read(notificationRepositoryProvider).markAllRead();
    _invalidate();
  }

  Future<void> delete(String id) async {
    await _ref.read(notificationRepositoryProvider).delete(id);
    _invalidate();
  }

  void _invalidate() {
    _ref.invalidate(notificationListProvider);
    _ref.invalidate(notificationGroupsProvider);
    _ref.invalidate(unreadCountProvider);
  }
}

final notificationActionsProvider = Provider<NotificationActions>(
  (ref) => NotificationActions(ref),
);
