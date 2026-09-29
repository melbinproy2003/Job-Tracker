import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/providers/auth_providers.dart';
import '../data/datasources/followups_remote_datasource.dart';
import '../data/repositories/followups_repository_impl.dart';
import '../domain/entities/follow_up.dart';
import '../domain/repositories/followups_repository.dart';

final followUpRemoteDataSourceProvider = Provider<FollowUpRemoteDataSource>((
  ref,
) {
  return FollowUpRemoteDataSource(ref.watch(dioProvider));
});

final followUpRepositoryProvider = Provider<FollowUpRepository>((ref) {
  return FollowUpRepositoryImpl(ref.watch(followUpRemoteDataSourceProvider));
});

class FollowUpGroups {
  const FollowUpGroups({
    required this.today,
    required this.tomorrow,
    required this.overdue,
    required this.completed,
    required this.later,
  });

  final List<FollowUp> today;
  final List<FollowUp> tomorrow;
  final List<FollowUp> overdue;
  final List<FollowUp> completed;
  final List<FollowUp> later;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

FollowUpGroups groupFollowUps(List<FollowUp> items, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final todayStart = DateTime(current.year, current.month, current.day);
  final tomorrowStart = todayStart.add(const Duration(days: 1));
  final dayAfter = tomorrowStart.add(const Duration(days: 1));

  final today = <FollowUp>[];
  final tomorrow = <FollowUp>[];
  final overdue = <FollowUp>[];
  final completed = <FollowUp>[];
  final later = <FollowUp>[];

  for (final item in items) {
    if (item.completed) {
      completed.add(item);
      continue;
    }
    final at = item.scheduledAt;
    if (item.isOverdue || at.isBefore(todayStart)) {
      overdue.add(item);
    } else if (_sameDay(at, todayStart) ||
        (at.isAfter(todayStart) && at.isBefore(tomorrowStart))) {
      today.add(item);
    } else if (_sameDay(at, tomorrowStart) ||
        (at.isAfter(tomorrowStart) && at.isBefore(dayAfter))) {
      tomorrow.add(item);
    } else {
      later.add(item);
    }
  }

  int byTime(FollowUp a, FollowUp b) => a.scheduledAt.compareTo(b.scheduledAt);
  today.sort(byTime);
  tomorrow.sort(byTime);
  overdue.sort(byTime);
  later.sort(byTime);
  completed.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

  return FollowUpGroups(
    today: today,
    tomorrow: tomorrow,
    overdue: overdue,
    completed: completed,
    later: later,
  );
}

final followupsProvider = FutureProvider.autoDispose<FollowUpGroups>((
  ref,
) async {
  final items = await ref.watch(followUpRepositoryProvider).getAll();
  return groupFollowUps(items);
});

final followupDetailProvider = FutureProvider.autoDispose
    .family<FollowUp, String>((ref, id) async {
      return ref.watch(followUpRepositoryProvider).getById(id);
    });

final applicationFollowupsProvider = FutureProvider.autoDispose
    .family<List<FollowUp>, String>((ref, appId) async {
      return ref
          .watch(followUpRepositoryProvider)
          .getAll(FollowUpListQuery(applicationId: appId));
    });
