import 'package:flutter/material.dart';

import '../../../../core/enums/application_status.dart';

class ApplicationStatusPresentation {
  const ApplicationStatusPresentation({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  static ApplicationStatusPresentation of(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.saved:
        return const ApplicationStatusPresentation(
          label: 'Saved',
          icon: Icons.bookmark_outline,
          color: Color(0xFF64748B),
        );
      case ApplicationStatus.applied:
        return const ApplicationStatusPresentation(
          label: 'Applied',
          icon: Icons.send_outlined,
          color: Color(0xFF5E6EF2),
        );
      case ApplicationStatus.viewed:
        return const ApplicationStatusPresentation(
          label: 'Viewed',
          icon: Icons.visibility_outlined,
          color: Color(0xFF0EA5E9),
        );
      case ApplicationStatus.shortlisted:
        return const ApplicationStatusPresentation(
          label: 'Shortlisted',
          icon: Icons.stars_outlined,
          color: Color(0xFF8B5CF6),
        );
      case ApplicationStatus.hrCall:
        return const ApplicationStatusPresentation(
          label: 'HR Call',
          icon: Icons.phone_outlined,
          color: Color(0xFFF59E0B),
        );
      case ApplicationStatus.technicalRound:
        return const ApplicationStatusPresentation(
          label: 'Technical Round',
          icon: Icons.code,
          color: Color(0xFF06B6D4),
        );
      case ApplicationStatus.interview:
        return const ApplicationStatusPresentation(
          label: 'Interview',
          icon: Icons.people_outline,
          color: Color(0xFF3B82F6),
        );
      case ApplicationStatus.finalRound:
        return const ApplicationStatusPresentation(
          label: 'Final Round',
          icon: Icons.flag_outlined,
          color: Color(0xFF6366F1),
        );
      case ApplicationStatus.offer:
        return const ApplicationStatusPresentation(
          label: 'Offer',
          icon: Icons.card_giftcard,
          color: Color(0xFF10B981),
        );
      case ApplicationStatus.accepted:
        return const ApplicationStatusPresentation(
          label: 'Accepted',
          icon: Icons.check_circle_outline,
          color: Color(0xFF059669),
        );
      case ApplicationStatus.rejected:
        return const ApplicationStatusPresentation(
          label: 'Rejected',
          icon: Icons.cancel_outlined,
          color: Color(0xFFEF4444),
        );
      case ApplicationStatus.withdrawn:
        return const ApplicationStatusPresentation(
          label: 'Withdrawn',
          icon: Icons.undo,
          color: Color(0xFF78716C),
        );
      case ApplicationStatus.noResponse:
        return const ApplicationStatusPresentation(
          label: 'No Response',
          icon: Icons.hourglass_empty,
          color: Color(0xFF94A3B8),
        );
    }
  }
}
