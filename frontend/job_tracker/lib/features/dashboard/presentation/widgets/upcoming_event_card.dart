import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/dashboard_summary.dart';

class UpcomingEventCard extends StatelessWidget {
  const UpcomingEventCard({super.key, required this.event, this.onTap});

  final DashboardUpcomingEvent event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final icon = event.isInterview
        ? Icons.event_available_outlined
        : Icons.notifications_active_outlined;
    final kindLabel = event.isInterview ? 'Interview' : 'Follow-up';

    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          kindLabel,
          if (event.companyName != null && event.companyName!.isNotEmpty)
            event.companyName,
          DateFormat.MMMd().add_jm().format(event.scheduledAt),
        ].whereType<String>().join(' · '),
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
