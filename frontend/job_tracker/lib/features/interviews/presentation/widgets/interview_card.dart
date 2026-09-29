import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/interview.dart';

class InterviewCard extends StatelessWidget {
  const InterviewCard({super.key, required this.interview, this.onTap});

  final Interview interview;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(
        interview.companyName?.isNotEmpty == true
            ? interview.companyName!
            : interview.displayTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        [
          interview.displayTitle,
          DateFormat.MMMd().add_jm().format(interview.scheduledAt),
          if (!interview.isUpcoming) interview.status.label,
        ].join(' · '),
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
