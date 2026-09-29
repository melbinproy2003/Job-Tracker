import 'package:flutter/material.dart';

import '../../../../core/enums/application_status.dart';
import 'application_status_presentation.dart';

class ApplicationStatusChip extends StatelessWidget {
  const ApplicationStatusChip({super.key, required this.status});

  final ApplicationStatus status;

  @override
  Widget build(BuildContext context) {
    final presentation = ApplicationStatusPresentation.of(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: presentation.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(presentation.icon, size: 14, color: presentation.color),
          const SizedBox(width: 6),
          Text(
            presentation.label,
            style: TextStyle(
              color: presentation.color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
