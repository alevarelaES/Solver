import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/portfolio/models/holding.dart';
import 'package:solver/features/portfolio/models/portfolio_summary.dart';
import 'package:solver/features/portfolio/widgets/allocation_chart.dart';
import 'package:solver/shared/widgets/app_panel.dart';

class PortfolioDashboard extends StatelessWidget {
  final PortfolioSummary summary;
  final List<Holding> holdings;

  const PortfolioDashboard({
    super.key,
    required this.summary,
    required this.holdings,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final bestPerformer = _bestPerformer();
    final topMovers = _topMovers();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI cards
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _KpiCard(
                label: 'VALEUR TOTALE',
                value: AppFormats.currency.format(summary.totalValue),
                icon: Icons.account_balance_wallet_outlined,
                color: AppColors.primary,
              ),
              _KpiCard(
                label: 'GAIN / PERTE',
                value: AppFormats.currency.format(summary.totalGainLoss),
                subtitle:
                    '${summary.totalGainLossPercent >= 0 ? '+' : ''}${summary.totalGainLossPercent.toStringAsFixed(2)}%',
                icon: summary.totalGainLoss >= 0
                    ? Icons.trending_up
                    : Icons.trending_down,
                color: summary.totalGainLoss >= 0
                    ? AppColors.success
                    : AppColors.danger,
              ),
              _KpiCard(
                label: 'POSITIONS',
                value: '${summary.holdingsCount}',
                icon: Icons.pie_chart_outline,
                color: AppColors.info,
              ),
              if (bestPerformer != null)
                _KpiCard(
                  label: 'MEILLEUR PERF.',
                  value: bestPerformer.symbol,
                  subtitle:
                      '+${bestPerformer.changePercent?.toStringAsFixed(2)}%',
                  icon: Icons.star_outline,
                  color: AppColors.warning,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // Allocation chart
          AllocationChart(holdings: holdings),
          const SizedBox(height: AppSpacing.xl),

          // Top movers
          if (topMovers.isNotEmpty) ...[
            Text(
              'TOP MOVERS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...topMovers.map(
              (h) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: AppPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Text(
                        h.symbol,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      if (h.name != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            h.name!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                        ),
                      ] else
                        const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: ((h.changePercent ?? 0) >= 0
                                  ? AppColors.success
                                  : AppColors.danger)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                        child: Text(
                          '${(h.changePercent ?? 0) >= 0 ? '+' : ''}${(h.changePercent ?? 0).toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: (h.changePercent ?? 0) >= 0
                                ? AppColors.success
                                : AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Holding? _bestPerformer() {
    final withChange =
        holdings.where((h) => h.changePercent != null).toList();
    if (withChange.isEmpty) return null;
    withChange.sort(
      (a, b) => (b.changePercent ?? 0).compareTo(a.changePercent ?? 0),
    );
    return withChange.first.changePercent != null &&
            withChange.first.changePercent! > 0
        ? withChange.first
        : null;
  }

  List<Holding> _topMovers() {
    final withChange =
        holdings.where((h) => h.changePercent != null).toList();
    withChange.sort(
      (a, b) => (b.changePercent ?? 0).abs().compareTo(
            (a.changePercent ?? 0).abs(),
          ),
    );
    return withChange.take(5).toList();
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return AppPanel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SizedBox(
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.robotoMono(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
