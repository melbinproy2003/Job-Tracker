import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/application_status_history.dart';
import 'application_status_presentation.dart';

class StatusTimeline extends StatelessWidget {
  const StatusTimeline({super.key, required this.history});

  final List<ApplicationStatusHistory> history;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Text('No status history yet.');
    }
    return Column(
      children: [
        for (var i = 0; i < history.length; i++) ...[
          _TimelineTile(entry: history[i], isLast: i == history.length - 1),
        ],
      ],
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.entry, required this.isLast});
  final ApplicationStatusHistory entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final presentation = ApplicationStatusPresentation.of(entry.newStatus);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: presentation.color,
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 48,
                color: Theme.of(context).dividerColor,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  presentation.label,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  DateFormat.yMMMd().add_jm().format(entry.changedAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (entry.note != null && entry.note!.isNotEmpty)
                  Text(entry.note!),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
