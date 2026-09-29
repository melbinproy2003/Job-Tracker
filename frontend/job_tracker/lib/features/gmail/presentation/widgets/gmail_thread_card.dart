import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/gmail_thread.dart';

/// One job-related thread in the Gmail inbox.
class GmailThreadCard extends StatelessWidget {
  const GmailThreadCard({super.key, required this.thread, this.onTap});

  final GmailThread thread;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accentFor(thread.matchStatus);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (thread.isJobRelated)
                    Icon(Icons.work_outline, size: 16, color: accent),
                  if (thread.isJobRelated) const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      thread.subject?.trim().isNotEmpty ?? false
                          ? thread.subject!.trim()
                          : '(no subject)',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if ((thread.snippet ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  thread.snippet!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _Pill(label: _statusLabel(thread.matchStatus), color: accent),
                  if (thread.detectedCategory != null)
                    _Pill(
                      label: thread.detectedCategory!.replaceAll('_', ' '),
                      color: theme.colorScheme.secondary,
                    ),
                  if (thread.suggestedStatus != null)
                    _Pill(
                      label:
                          'Suggests ${_prettyStatus(thread.suggestedStatus!)}',
                      color: theme.colorScheme.tertiary,
                    ),
                  if (thread.matchConfidence != null)
                    _Pill(
                      label:
                          '${MatchConfidence.fromScore(thread.matchConfidence).label} confidence',
                      color: theme.colorScheme.outline,
                    ),
                  if (thread.hasInterviewSuggestion)
                    const _Pill(
                      label: 'Interview detected',
                      color: Color(0xFF3D4DB8),
                    ),
                ],
              ),
              if (thread.lastMessageAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  DateFormat.yMMMd().add_jm().format(thread.lastMessageAt!),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Color _accentFor(GmailMatchStatus status) => switch (status) {
    GmailMatchStatus.matched => const Color(0xFF0F7B6C),
    GmailMatchStatus.suggested => const Color(0xFFB26A00),
    GmailMatchStatus.ignored => const Color(0xFF6B7280),
    GmailMatchStatus.unmatched => const Color(0xFF5E6EF2),
  };

  static String _statusLabel(GmailMatchStatus status) => switch (status) {
    GmailMatchStatus.matched => 'Linked',
    GmailMatchStatus.suggested => 'Needs review',
    GmailMatchStatus.ignored => 'Ignored',
    GmailMatchStatus.unmatched => 'Unmatched',
  };

  static String _prettyStatus(String apiValue) {
    final lower = apiValue.toLowerCase().split('_');
    return lower
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
