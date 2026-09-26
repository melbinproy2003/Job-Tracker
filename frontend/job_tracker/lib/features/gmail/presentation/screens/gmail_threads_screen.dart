import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../shared/empty_states/empty_view.dart';
import '../../../../shared/error/error_view.dart';
import '../../../../shared/loading/loading_view.dart';
import '../../providers/gmail_providers.dart';
import '../widgets/gmail_thread_card.dart';

/// Optional "Gmail Inbox" (Phase 5 §35) — job-related emails only.
class GmailThreadsScreen extends ConsumerWidget {
  const GmailThreadsScreen({super.key, this.applicationId});

  final String? applicationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threads = ref.watch(gmailThreadsProvider(applicationId));

    return Scaffold(
      appBar: AppBar(
        title: Text(applicationId == null ? 'Job Emails' : 'Emails'),
        actions: [
          IconButton(
            tooltip: 'Sync now',
            icon: const Icon(Icons.sync),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final notifier = ref.read(gmailSyncControllerProvider.notifier);
              final ok = await notifier.sync();
              ref.invalidate(gmailThreadsProvider(applicationId));
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    ok ? 'Sync completed' : 'Sync failed. Try again later.',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: threads.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: 'Could not load emails.',
          onRetry: () => ref.invalidate(gmailThreadsProvider(applicationId)),
        ),
        data: (items) {
          if (items.isEmpty) {
            return EmptyView(
              title: 'No job-related emails',
              message: applicationId == null
                  ? 'Run a sync to detect job application emails.'
                  : 'No emails are linked to this application yet.',
            );
          }
          final unresolved = items.where((t) => t.isUnresolved).toList();
          final resolved = items.where((t) => !t.isUnresolved).toList();

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(gmailThreadsProvider(applicationId)),
            child: ListView(
              children: [
                if (unresolved.isNotEmpty) ...[
                  const _Header('Needs your review'),
                  ...unresolved.map(
                    (t) => GmailThreadCard(
                      thread: t,
                      onTap: () => context.push(RouteNames.gmailLinkPath(t.id)),
                    ),
                  ),
                ],
                if (resolved.isNotEmpty) ...[
                  const _Header('Linked emails'),
                  ...resolved.map(
                    (t) => GmailThreadCard(
                      thread: t,
                      onTap: () =>
                          context.push(RouteNames.gmailThreadDetailPath(t.id)),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
