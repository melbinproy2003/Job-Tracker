import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/providers/auth_providers.dart';
import '../data/datasources/interviews_remote_datasource.dart';
import '../data/repositories/interviews_repository_impl.dart';
import '../domain/entities/interview.dart';
import '../domain/repositories/interviews_repository.dart';

final interviewRemoteDataSourceProvider = Provider<InterviewRemoteDataSource>((
  ref,
) {
  return InterviewRemoteDataSource(ref.watch(dioProvider));
});

final interviewRepositoryProvider = Provider<InterviewRepository>((ref) {
  return InterviewRepositoryImpl(ref.watch(interviewRemoteDataSourceProvider));
});

class InterviewGroups {
  const InterviewGroups({required this.upcoming, required this.past});
  final List<Interview> upcoming;
  final List<Interview> past;
}

/// Groups interviews into Upcoming vs Past.
InterviewGroups groupInterviews(List<Interview> items) {
  final now = DateTime.now();
  final upcoming = <Interview>[];
  final past = <Interview>[];

  for (final item in items) {
    final isActiveStatus = item.isUpcoming;
    final isFuture = !item.scheduledAt.isBefore(now);
    if (isActiveStatus && isFuture) {
      upcoming.add(item);
    } else {
      past.add(item);
    }
  }

  upcoming.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  past.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
  return InterviewGroups(upcoming: upcoming, past: past);
}

final interviewsProvider = FutureProvider.autoDispose<InterviewGroups>((
  ref,
) async {
  final items = await ref.watch(interviewRepositoryProvider).getAll();
  return groupInterviews(items);
});

final interviewDetailProvider = FutureProvider.autoDispose
    .family<Interview, String>((ref, id) async {
      return ref.watch(interviewRepositoryProvider).getById(id);
    });

final applicationInterviewsProvider = FutureProvider.autoDispose
    .family<List<Interview>, String>((ref, appId) async {
      return ref.watch(interviewRepositoryProvider).getForApplication(appId);
    });
