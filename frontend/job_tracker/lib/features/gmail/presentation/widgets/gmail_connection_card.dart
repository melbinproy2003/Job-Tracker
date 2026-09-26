import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/gmail_providers.dart';

/// Compact "last synced" / "never" label.
String lastSyncedLabel(DateTime? at, {DateTime? now}) {
  if (at == null) return 'Never synced';
  final reference = now ?? DateTime.now();
  final diff = reference.difference(at);
  if (diff.inMinutes < 1) return 'Last synced just now';
  if (diff.inMinutes < 60) return 'Last synced ${diff.inMinutes} min ago';
  if (diff.inHours < 24) return 'Last synced ${diff.inHours} h ago';
  return 'Last synced ${DateFormat.yMMMd().add_jm().format(at)}';
}

/// Connected / not-connected header for the Gmail settings screen.
class GmailConnectionCard extends ConsumerWidget {
  const GmailConnectionCard({
    super.key,
    required this.onConnect,
    required this.onDisconnect,
    required this.onSync,
    this.syncing = false,
  });

  final VoidCallback onConnect;
  final VoidCallback? onDisconnect;
  final VoidCallback? onSync;
  final bool syncing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accountAsync = ref.watch(gmailAccountProvider);

    return accountAsync.when(
      loading: () => const Card(
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, _) => Card(
        margin: const EdgeInsets.all(16),
        child: ListTile(
          leading: const Icon(Icons.error_outline),
          title: const Text('Could not load Gmail status'),
          subtitle: Text('$error'),
          trailing: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(gmailAccountsProvider),
          ),
        ),
      ),
      data: (account) {
        if (account == null || !account.connected) {
          return Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gmail Integration',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connect your Gmail account to automatically detect job '
                    'application emails.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onConnect,
                    icon: const Icon(Icons.link, size: 18),
                    label: const Text('Connect Gmail'),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Gmail Connected',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SelectableText(account.email, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 4),
                Text(
                  lastSyncedLabel(account.lastSyncAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: syncing ? null : onSync,
                      icon: syncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync, size: 18),
                      label: Text(syncing ? 'Syncing…' : 'Sync Now'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: onDisconnect,
                      icon: const Icon(Icons.link_off, size: 18),
                      label: const Text('Disconnect'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Inline summary of the last completed sync.
class GmailSyncSummary extends ConsumerWidget {
  const GmailSyncSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gmailSyncControllerProvider);
    final result = state.lastResult;
    if (result == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sync completed',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text('${result.messagesChecked} emails checked'),
            Text('${result.jobRelatedFound} job-related found'),
            Text('${result.matchesSuggested} match suggested'),
          ],
        ),
      ),
    );
  }
}
