import 'package:flutter/material.dart';
import 'package:solver/shared/widgets/status_chip_row.dart';

class GoalsStatsStrip extends StatelessWidget {
  final double progressionPercent;
  final double mensuelCumule;
  final int objectifsCount;
  final Map<String, int> statusCounts; // e.g., {'Urgence': 1, 'Attention': 1, 'Retard': 0}

  const GoalsStatsStrip({
    super.key,
    required this.progressionPercent,
    required this.mensuelCumule,
    required this.objectifsCount,
    required this.statusCounts,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: _StatItem(
                label: 'Progression moyenne',
                value: '${progressionPercent.toStringAsFixed(1)}%',
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: _StatItem(
                label: 'Mensuel cumulé',
                value: '${mensuelCumule.toInt()} CHF',
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: _AlertsColumn(statusCounts: statusCounts),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: _StatItem(
                label: 'Atteints',
                value: '$objectifsCount\nObjectifs',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final TextAlign textAlign;

  const _StatItem({
    required this.label,
    required this.value,
    this.textAlign = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: textAlign == TextAlign.center 
          ? CrossAxisAlignment.center 
          : CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: textAlign,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _AlertsColumn extends StatelessWidget {
  final Map<String, int> statusCounts;

  const _AlertsColumn({required this.statusCounts});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Alertes',
          style: theme.textTheme.labelMedium?.copyWith(
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        StatusChipColumn(
          statusCounts: statusCounts,
          statusColors: {
            'Urgence': theme.colorScheme.error,
            'Attention': Colors.amber,
            'En retard': isDark ? Colors.white30 : Colors.black26, 
            'Actif': theme.colorScheme.primary,
            'En cours': Colors.amber,
            'Réussi': Colors.blue,
          },
        ),
      ],
    );
  }
}
