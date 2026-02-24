import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/settings/currency_settings_provider.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/portfolio/models/holding.dart';
import 'package:solver/features/portfolio/widgets/mini_sparkline.dart';
import 'package:solver/shared/widgets/app_panel.dart';

class HoldingCard extends ConsumerWidget {
  final Holding holding;
  final List<double>? sparklinePrices;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final ValueChanged<bool>? onArchive;

  const HoldingCard({
    super.key,
    required this.holding,
    this.sparklinePrices,
    this.onTap,
    this.onDelete,
    this.onArchive,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appCurrencyProvider);
    final dayChange = holding.changePercent ?? 0;
    final totalChange = holding.totalGainLoss ?? 0;
    final dayColor = dayChange >= 0 ? AppColors.success : AppColors.danger;
    final totalColor = totalChange >= 0 ? AppColors.success : AppColors.danger;

    return AppPanel(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      holding.symbol,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ((holding.name ?? '').isNotEmpty)
                      Text(
                        holding.name!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                  ],
                ),
              ),
              MiniSparkline(
                prices: sparklinePrices,
                changePercent: dayChange,
                color: dayColor,
                width: 56,
                height: 22,
              ),
              const SizedBox(width: AppSpacing.sm),
              _ChangeBadge(percent: dayChange, color: dayColor),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'archive') onArchive?.call(true);
                  if (value == 'delete') onDelete?.call();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<String>(
                    value: 'archive',
                    child: Text('Archiver'),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Text('Supprimer'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.sm,
            children: [
              _Metric(
                label: 'Quantite',
                value: holding.quantity.toStringAsFixed(2),
              ),
              _Metric(
                label: 'Prix actuel',
                value: AppFormats.formatFromCurrency(
                    holding.currentPrice, holding.currency),
              ),
              _Metric(
                label: 'Valeur',
                value: AppFormats.formatFromCurrency(
                    holding.totalValue, holding.currency),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Performance totale: ${AppFormats.formatFromCurrency(holding.totalGainLoss, holding.currency)} '
            '(${_formatPercent(holding.totalGainLossPercent)})',
            style: TextStyle(
              color: totalColor,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          if (holding.isStale)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'Prix en cache (donnees stale)',
                style: TextStyle(fontSize: 11, color: AppColors.warning),
              ),
            ),
        ],
      ),
    );
  }

  String _formatPercent(double? value) {
    if (value == null) return '--';
    final sign = value >= 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(2)}%';
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ChangeBadge extends StatelessWidget {
  final double percent;
  final Color color;

  const _ChangeBadge({required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    final sign = percent >= 0 ? '+' : '';

    return Container(
      margin: const EdgeInsets.only(right: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.r16),
      ),
      child: Text(
        '$sign${percent.toStringAsFixed(2)}%',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
