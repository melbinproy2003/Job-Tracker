import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/application.dart';
import 'application_status_chip.dart';

class ApplicationCard extends StatelessWidget {
  const ApplicationCard({
    super.key,
    required this.application,
    required this.onTap,
  });

  final Application application;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = application.appliedAt;
    final dateLabel = date == null ? '—' : DateFormat.yMMMd().format(date);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                application.company.name,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                application.jobTitle,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  if (application.location != null &&
                      application.location!.isNotEmpty)
                    _Meta(
                      icon: Icons.place_outlined,
                      text: application.location!,
                    ),
                  if (application.employmentType != null &&
                      application.employmentType!.isNotEmpty)
                    _Meta(
                      icon: Icons.work_outline,
                      text: application.employmentType!,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ApplicationStatusChip(status: application.status),
                  const Spacer(),
                  Text(
                    'Applied: $dateLabel',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
