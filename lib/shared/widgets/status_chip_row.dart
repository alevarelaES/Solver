import 'package:flutter/material.dart';
import 'package:solver/shared/widgets/premium_card_base.dart';
import 'package:solver/shared/widgets/color_dot.dart';

class StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const StatusChip({
    super.key,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PremiumCardBase(
      variant: PremiumCardVariant.chip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ColorDot(color: color, size: 8),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusChipRow extends StatelessWidget {
  final Map<String, int> statusCounts;
  final Map<String, Color> statusColors;

  const StatusChipRow({
    super.key,
    required this.statusCounts,
    required this.statusColors,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: statusCounts.entries.map((entry) {
          final label = entry.key;
          final count = entry.value;
          final color = statusColors[label] ?? Colors.grey;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: StatusChip(
              label: label,
              count: count,
              color: color,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class StatusChipColumn extends StatelessWidget {
  final Map<String, int> statusCounts;
  final Map<String, Color> statusColors;

  const StatusChipColumn({
    super.key,
    required this.statusCounts,
    required this.statusColors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: statusCounts.entries.map((entry) {
        final label = entry.key;
        final count = entry.value;
        final color = statusColors[label] ?? Colors.grey;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: StatusChip(
            label: label,
            count: count,
            color: color,
          ),
        );
      }).toList(),
    );
  }
}
