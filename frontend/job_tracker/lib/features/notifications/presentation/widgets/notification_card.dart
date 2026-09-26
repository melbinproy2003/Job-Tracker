import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/enums/notification_type.dart';
import '../../domain/entities/app_notification.dart';

/// Relative time label ("2 minutes ago") used in the notification centre.
String relativeTime(DateTime? time, {DateTime? now}) {
  if (time == null) return '';
  final reference = now ?? DateTime.now();
  final diff = reference.difference(time);

  if (diff.isNegative) {
    final ahead = time.difference(reference);
    if (ahead.inMinutes < 60) return 'in ${ahead.inMinutes}m';
    if (ahead.inHours < 24) return 'in ${ahead.inHours}h';
    return 'in ${ahead.inDays}d';
  }
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat.yMMMd().format(time);
}

IconData notificationIcon(AppNotificationType type) => switch (type) {
  AppNotificationType.interviewReminder => Icons.event_available,
  AppNotificationType.followupReminder => Icons.schedule,
  AppNotificationType.followupOverdue => Icons.warning_amber,
  AppNotificationType.gmailEmailDetected => Icons.mail_outline,
  AppNotificationType.applicationStatusSuggestion => Icons.auto_awesome,
  AppNotificationType.system => Icons.notifications_none,
};

Color notificationColor(AppNotificationType type) => switch (type) {
  AppNotificationType.interviewReminder => const Color(0xFF3D4DB8),
  AppNotificationType.followupReminder => const Color(0xFF0F7B6C),
  AppNotificationType.followupOverdue => const Color(0xFFB3261E),
  AppNotificationType.gmailEmailDetected => const Color(0xFF5E6EF2),
  AppNotificationType.applicationStatusSuggestion => const Color(0xFF8A5CF6),
  AppNotificationType.system => const Color(0xFF6B7280),
};

/// One row in the notification centre.
class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.notification,
    this.onTap,
    this.onDismissed,
  });

  final AppNotification notification;
  final VoidCallback? onTap;
  final VoidCallback? onDismissed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = notificationColor(notification.type);

    return Dismissible(
      key: ValueKey(notification.id),
      direction: onDismissed == null
          ? DismissDirection.none
          : DismissDirection.endToStart,
      onDismissed: (_) => onDismissed?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: theme.colorScheme.errorContainer,
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          // Unread rows are tinted so the inbox reads as a to-do list.
          color: notification.read ? null : color.withValues(alpha: 0.06),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  notificationIcon(notification.type),
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: notification.read
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!notification.read)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      relativeTime(
                        notification.createdAt ?? notification.sentAt,
                      ),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
