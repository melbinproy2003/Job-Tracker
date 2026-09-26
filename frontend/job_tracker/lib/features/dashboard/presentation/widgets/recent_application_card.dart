import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/enums/application_status.dart';
import '../../../applications/presentation/widgets/application_status_chip.dart';
import '../../domain/entities/dashboard_summary.dart';

class RecentApplicationCard extends StatelessWidget {
  const RecentApplicationCard({
    super.key,
    required this.application,
    this.onTap,
  });

  final DashboardRecentApplication application;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      title: Text(
        application.companyName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        application.jobTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ApplicationStatusChip(
            status: ApplicationStatus.fromApi(application.status),
          ),
          if (application.updatedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              DateFormat.MMMd().format(application.updatedAt!),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
