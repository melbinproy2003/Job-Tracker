import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../shared/empty_states/empty_view.dart';
import '../../../../shared/error/error_view.dart';
import '../../../../shared/loading/loading_view.dart';
import '../../providers/interviews_providers.dart';
import '../widgets/interview_card.dart';

class InterviewsScreen extends ConsumerWidget {
  const InterviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(interviewsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Interviews')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RouteNames.addInterview),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'Unable to load interviews.',
          onRetry: () => ref.invalidate(interviewsProvider),
        ),
        data: (groups) {
          if (groups.upcoming.isEmpty && groups.past.isEmpty) {
            return const EmptyView(
              title: 'No interviews yet',
              message: 'Schedule your first interview from an application.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(interviewsProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              children: [
                if (groups.upcoming.isNotEmpty) ...[
                  Text(
                    'Upcoming',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Divider(),
                  for (final i in groups.upcoming)
                    InterviewCard(
                      interview: i,
                      onTap: () =>
                          context.push(RouteNames.interviewDetailPath(i.id)),
                    ),
                  const SizedBox(height: 20),
                ],
                if (groups.past.isNotEmpty) ...[
                  Text(
                    'Past',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Divider(),
                  for (final i in groups.past)
                    InterviewCard(
                      interview: i,
                      onTap: () =>
                          context.push(RouteNames.interviewDetailPath(i.id)),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
