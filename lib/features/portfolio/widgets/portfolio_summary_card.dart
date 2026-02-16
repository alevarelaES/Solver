import 'package:flutter/material.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/portfolio/models/portfolio_summary.dart';
import 'package:solver/shared/widgets/app_panel.dart';

class PortfolioSummaryCard extends StatelessWidget {
  final PortfolioSummary summary;

  const PortfolioSummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final gainColor = summary.totalGainLoss >= 0
        ? AppColors.success
        : AppColors.danger;

    return AppPanel(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      variant: AppPanelVariant.elevated,
      child: Wrap(
        spacing: AppSpacing.xl,
        runSpacing: AppSpacing.lg,
        children: [
          _SummaryMetric(
            label: 'Valeur totale',
            value: AppFormats.currency.format(summary.totalValue),
            icon: Icons.account_balance_wallet_outlined,
            color: AppColors.primary,
          ),
          _SummaryMetric(
            label: 'Gain / Perte',
            value:
                '${AppFormats.currency.format(summary.totalGainLoss)} (${_formatPercent(summary.totalGainLossPercent)})',
            icon: summary.totalGainLoss >= 0
                ? Icons.trending_up
                : Icons.trending_down,
            color: gainColor,
          ),
          _SummaryMetric(
            label: 'Positions',
            value: '${summary.holdingsCount}',
            icon: Icons.candlestick_chart,
            color: AppColors.info,
          ),
        ],
      ),
    );
  }

  String _formatPercent(double value) {
    final sign = value >= 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(2)}%';
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.r10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
