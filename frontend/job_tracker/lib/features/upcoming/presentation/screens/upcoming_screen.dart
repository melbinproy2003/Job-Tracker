import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/route_names.dart';
import '../../../../shared/empty_states/empty_view.dart';
import '../../../../shared/error/error_view.dart';
import '../../../../shared/loading/loading_view.dart';
import '../../providers/upcoming_providers.dart';

class UpcomingScreen extends ConsumerWidget {
  const UpcomingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(upcomingItemsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Upcoming')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'Unable to load upcoming events.',
          onRetry: () => ref.invalidate(upcomingItemsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyView(
              title: 'Nothing upcoming',
              message: 'Scheduled interviews and follow-ups will appear here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(upcomingItemsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    item.isInterview
                        ? Icons.event_available_outlined
                        : Icons.notifications_active_outlined,
                  ),
                  title: Text(item.title),
                  subtitle: Text(
                    [
                      DateFormat.MMMd().add_jm().format(item.scheduledAt),
                      if (item.companyName != null) item.companyName!,
                      if (item.jobTitle != null) item.jobTitle!,
                    ].join(' · '),
                  ),
                  onTap: () {
                    if (item.isInterview) {
                      context.push(
                        RouteNames.interviewDetailPath(item.interview!.id),
                      );
                    } else {
                      context.push(
                        RouteNames.applicationDetailPath(
                          item.followUp!.applicationId,
                        ),
                      );
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
