import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/route_names.dart';
import '../../../../shared/error/error_view.dart';
import '../../../../shared/loading/loading_view.dart';
import '../../providers/gmail_providers.dart';

/// Read-only view of a detected email (Phase 5 §36).
///
/// This is not an email client: no reply, no archive, no mark-as-read. It shows
/// only what was already extracted for job tracking.
class GmailMessageDetailScreen extends ConsumerWidget {
  const GmailMessageDetailScreen({super.key, required this.messageId});

  final String messageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(gmailMessageDetailProvider(messageId));

    return Scaffold(
      appBar: AppBar(title: const Text('Email')),
      body: message.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: 'Could not load this email.',
          onRetry: () => ref.invalidate(gmailMessageDetailProvider(messageId)),
        ),
        data: (item) {
          final theme = Theme.of(context);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if ((item.subject ?? '').isNotEmpty)
                Text(
                  item.subject!,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(height: 16),
              _Field(label: 'From', value: item.fromAddress ?? '—'),
              _Field(label: 'To', value: item.toAddress ?? '—'),
              if (item.receivedAt != null)
                _Field(
                  label: 'Received',
                  value: DateFormat.yMMMd().add_jm().format(item.receivedAt!),
                ),
              if (item.detectedCategory != null)
                _Field(label: 'Detected as', value: item.detectedCategory!),
              if (item.applicationId != null) ...[
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: () => context.push(
                    RouteNames.applicationDetailPath(item.applicationId!),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Open application'),
                ),
              ],
              const Divider(height: 32),
              Text(
                'Email summary',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _summaryFor(item.detectedCategory, item.isJobRelated),
                style: theme.textTheme.bodyMedium,
              ),
              if ((item.snippet ?? '').isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Excerpt',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(item.snippet!, style: theme.textTheme.bodyMedium),
              ],
              if ((item.bodyText ?? '').isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Extracted text',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  item.bodyText!,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  static String _summaryFor(String? category, bool isJobRelated) {
    if (!isJobRelated) return 'Not identified as a job-related email.';
    switch (category?.toUpperCase()) {
      case 'INTERVIEW':
        return 'Interview invitation detected.';
      case 'REJECTION':
        return 'This email may indicate that your application was not selected.';
      case 'OFFER':
        return 'Possible offer email detected.';
      case 'SHORTLIST':
        return 'Shortlisting / next-round notification detected.';
      case 'RECEIVED':
        return 'Application confirmation email detected.';
      default:
        return 'Job-related email detected.';
    }
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
