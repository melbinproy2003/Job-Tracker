import 'package:flutter/material.dart';

import '../../../../core/enums/application_status.dart';
import '../../../applications/presentation/widgets/application_status_presentation.dart';

class StatusDistribution extends StatelessWidget {
  const StatusDistribution({super.key, required this.distribution});

  final Map<String, int> distribution;

  @override
  Widget build(BuildContext context) {
    if (distribution.isEmpty) {
      return Text(
        'No status data yet',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    final entries = distribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = entries.first.value.toDouble().clamp(1, double.infinity);

    return Column(
      children: [
        for (final e in entries) ...[
          _BarRow(
            label: ApplicationStatus.fromApi(e.key).label,
            value: e.value,
            fraction: e.value / max,
            color: ApplicationStatusPresentation.of(
              ApplicationStatus.fromApi(e.key),
            ).color,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
  });

  final String label;
  final int value;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            Text('$value', style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.15),
            color: color,
          ),
        ),
      ],
    );
  }
}
