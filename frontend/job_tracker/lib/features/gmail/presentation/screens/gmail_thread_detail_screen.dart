import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/route_names.dart';
import '../../../../shared/empty_states/empty_view.dart';
import '../../../../shared/error/error_view.dart';
import '../../../../shared/loading/loading_view.dart';
import '../../domain/entities/gmail_thread.dart';
import '../../providers/gmail_providers.dart';

/// Read-only view of a detected job-related thread.
///
/// Only metadata the backend already extracted is shown; there is no
/// "reply", "archive" or "mark as read" because this app is not a mail client.
/// When the thread is still unresolved it offers a review action, which is
/// where the explicit linking confirmation lives.
class GmailThreadDetailScreen extends ConsumerWidget {
  const GmailThreadDetailScreen({super.key, required this.threadId});

  final String threadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadAsync = ref.watch(gmailThreadDetailProvider(threadId));

    return Scaffold(
      appBar: AppBar(title: const Text('Email thread')),
      body: threadAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: 'Could not load this thread.',
          onRetry: () => ref.invalidate(gmailThreadDetailProvider(threadId)),
        ),
        data: (thread) {
          if (thread.id.isEmpty) {
            return const EmptyView(
              title: 'Thread not found',
              message: 'It may have been removed.',
            );
          }
          return _Body(thread: thread);
        },
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.thread});
  final GmailThread thread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final confidence = MatchConfidence.fromScore(thread.matchConfidence);

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (thread.subject ?? '').trim().isEmpty
                    ? 'Job-related email'
                    : thread.subject!.trim(),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (thread.lastMessageAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  DateFormat.yMMMd().add_jm().format(thread.lastMessageAt!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (thread.isUnresolved)
          _ResolveBanner(
            hasConfidence: thread.matchConfidence != null,
            confidence: confidence,
            onReview: () => context.push(RouteNames.gmailLinkPath(thread.id)),
          )
        else if (thread.applicationId != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => context.push(
                    RouteNames.applicationDetailPath(thread.applicationId!),
                  ),
                  icon: const Icon(Icons.work_outline, size: 18),
                  label: const Text('Open linked application'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Unlink email?'),
                        content: const Text(
                          'This removes the link only. Application status and '
                          'interviews are unchanged.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Unlink'),
                          ),
                        ],
                      ),
                    );
                    if (ok != true || !context.mounted) return;
                    final appId = thread.applicationId;
                    final success = await ref
                        .read(gmailMatchControllerProvider.notifier)
                        .unlink(thread.id);
                    if (!context.mounted) return;
                    if (success) {
                      ref.invalidate(gmailThreadDetailProvider(thread.id));
                      ref.invalidate(gmailThreadsProvider(appId));
                      ref.invalidate(gmailApplicationTimelineProvider(appId!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Email unlinked')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not unlink')),
                      );
                    }
                  },
                  icon: const Icon(Icons.link_off, size: 18),
                  label: const Text('Unlink from application'),
                ),
              ],
            ),
          ),
        if (thread.detectedCategory != null ||
            thread.matchedSignals.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (thread.detectedCategory != null)
                  Text(
                    'Category: ${thread.detectedCategory!.replaceAll('_', ' ')}',
                    style: theme.textTheme.bodyMedium,
                  ),
                if (thread.matchedSignals.isNotEmpty)
                  Text(
                    'Signals: ${thread.matchedSignals.take(5).join(', ')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        const Divider(height: 24),
        if ((thread.snippet ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Latest message',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(thread.snippet!, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        if (thread.participants.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Participants',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                ...thread.participants.map(
                  (p) => Text(p, style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
          ),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _ResolveBanner extends StatelessWidget {
  const _ResolveBanner({
    required this.hasConfidence,
    required this.confidence,
    required this.onReview,
  });

  final bool hasConfidence;
  final MatchConfidence confidence;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This email is not linked yet',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'A possible match was found. Nothing has been changed — review it '
            'to link the email to an application.',
            style: theme.textTheme.bodyMedium,
          ),
          if (hasConfidence) ...[
            const SizedBox(height: 6),
            Text('Match confidence: ${confidence.label}'),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onReview,
            icon: const Icon(Icons.rule, size: 18),
            label: const Text('Review match'),
          ),
        ],
      ),
    );
  }
}
