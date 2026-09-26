import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/follow_up.dart';

class FollowUpCard extends StatelessWidget {
  const FollowUpCard({
    super.key,
    required this.followUp,
    this.onComplete,
    this.onUndo,
    this.onEdit,
    this.onDelete,
  });

  final FollowUp followUp;
  final VoidCallback? onComplete;
  final VoidCallback? onUndo;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final overdue = followUp.isOverdue && !followUp.completed;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(
        followUp.completed
            ? Icons.check_circle
            : overdue
            ? Icons.warning_amber_rounded
            : Icons.radio_button_unchecked,
        color: followUp.completed
            ? Colors.green
            : overdue
            ? Colors.orange
            : null,
      ),
      title: Text(
        followUp.title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          decoration: followUp.completed ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(
        [
          if (followUp.companyName != null) followUp.companyName!,
          if (followUp.jobTitle != null) followUp.jobTitle!,
          if (followUp.completed && followUp.completedAt != null)
            'Completed ${DateFormat.MMMd().format(followUp.completedAt!)}'
          else if (overdue)
            'Overdue · ${DateFormat.MMMd().add_jm().format(followUp.scheduledAt)}'
          else
            DateFormat.MMMd().add_jm().format(followUp.scheduledAt),
        ].join('\n'),
      ),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          switch (v) {
            case 'complete':
              onComplete?.call();
            case 'undo':
              onUndo?.call();
            case 'edit':
              onEdit?.call();
            case 'delete':
              onDelete?.call();
          }
        },
        itemBuilder: (context) => [
          if (!followUp.completed)
            const PopupMenuItem(value: 'complete', child: Text('Complete')),
          if (followUp.completed)
            const PopupMenuItem(value: 'undo', child: Text('Reopen')),
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}
