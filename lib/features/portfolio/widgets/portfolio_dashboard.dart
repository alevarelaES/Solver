import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/portfolio/models/holding.dart';
import 'package:solver/features/portfolio/models/portfolio_summary.dart';
import 'package:solver/features/portfolio/widgets/allocation_chart.dart';
import 'package:solver/features/portfolio/widgets/asset_logo.dart';
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
    final bestPerformer = _bestPerformer();
    final topMovers = _topMovers();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroCard(summary: summary, holdings: holdings),
          const SizedBox(height: AppSpacing.md),
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
                      '+${(bestPerformer.changePercent ?? 0).toStringAsFixed(2)}%',
                  icon: Icons.rocket_launch_outlined,
                  color: AppColors.warning,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AllocationChart(holdings: holdings),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(label: 'TOP MOVERS'),
          const SizedBox(height: AppSpacing.sm),
          if (topMovers.isEmpty)
            AppPanel(
              child: Text(
                'Ajoutez des actifs pour voir les movers.',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final crossCount = constraints.maxWidth > 980 ? 2 : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossCount,
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 4.1,
                  ),
                  itemCount: topMovers.length,
                  itemBuilder: (context, index) {
                    final h = topMovers[index];
                    final pct = h.changePercent ?? 0;
                    final up = pct >= 0;
                    final color = up ? AppColors.success : AppColors.danger;

                    return AppPanel(
                      variant: AppPanelVariant.elevated,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          AssetLogo(
                            symbol: h.symbol,
                            assetType: h.assetType,
                            size: 28,
                            borderRadius: 999,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  h.symbol,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if ((h.name ?? '').isNotEmpty)
                                  Text(
                                    h.name!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (h.totalValue != null)
                            Text(
                              AppFormats.currency.format(h.totalValue),
                              style: GoogleFonts.robotoMono(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          const SizedBox(width: AppSpacing.md),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.11),
                              borderRadius: BorderRadius.circular(AppRadius.xs),
                            ),
                            child: Text(
                              '${up ? '+' : ''}${pct.toStringAsFixed(2)}%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(label: 'POSITIONS'),
          const SizedBox(height: AppSpacing.sm),
          _PositionsTable(holdings: holdings),
        ],
      ),
    );
  }

  Holding? _bestPerformer() {
    final withChange = holdings.where((h) => h.changePercent != null).toList();
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
    final withChange = holdings.where((h) => h.changePercent != null).toList();
    withChange.sort(
      (a, b) =>
          (b.changePercent ?? 0).abs().compareTo((a.changePercent ?? 0).abs()),
    );
    return withChange.take(6).toList();
  }
}

class _HeroCard extends StatelessWidget {
  final PortfolioSummary summary;
  final List<Holding> holdings;

  const _HeroCard({required this.summary, required this.holdings});

  @override
  Widget build(BuildContext context) {
    final up = summary.totalGainLoss >= 0;
    final perfColor = up ? AppColors.success : AppColors.danger;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final total = holdings.fold<double>(
      0,
      (sum, h) => sum + (h.totalValue ?? 0),
    );
    final cryptoWeight = _weightFor('crypto', total);
    final stockWeight = _weightFor('stock', total);
    final etfWeight = _weightFor('etf', total);

    return AppPanel(
      variant: AppPanelVariant.elevated,
      backgroundColor: isDark
          ? AppColors.portfolioSurfaceDark
          : AppColors.portfolioSurfaceLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'PORTFOLIO SNAPSHOT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: perfColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.r16),
                ),
                child: Text(
                  '${up ? '+' : ''}${summary.totalGainLossPercent.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: perfColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppFormats.currency.format(summary.totalValue),
            style: GoogleFonts.robotoMono(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'P/L total: ${AppFormats.currency.format(summary.totalGainLoss)}',
            style: TextStyle(color: perfColor, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _AllocationChip(
                label: 'Stocks',
                percent: stockWeight,
                color: AppColors.primary,
              ),
              _AllocationChip(
                label: 'Crypto',
                percent: cryptoWeight,
                color: AppColors.info,
              ),
              _AllocationChip(
                label: 'ETF',
                percent: etfWeight,
                color: AppColors.warning,
              ),
              _AllocationChip(
                label: 'Positions',
                percent: summary.holdingsCount.toDouble(),
                color: AppColors.textSecondaryLight,
                asCount: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _weightFor(String type, double total) {
    if (total <= 0) return 0;
    final subtotal = holdings
        .where((h) => h.assetType == type)
        .fold<double>(0, (sum, h) => sum + (h.totalValue ?? 0));
    return subtotal / total * 100;
  }
}

class _AllocationChip extends StatelessWidget {
  final String label;
  final double percent;
  final Color color;
  final bool asCount;

  const _AllocationChip({
    required this.label,
    required this.percent,
    required this.color,
    this.asCount = false,
  });

  @override
  Widget build(BuildContext context) {
    final value = asCount
        ? percent.toStringAsFixed(0)
        : '${percent.toStringAsFixed(1)}%';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(AppRadius.r16),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;

  const _SectionTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight,
      ),
    );
  }
}

class _PositionsTable extends StatelessWidget {
  final List<Holding> holdings;

  const _PositionsTable({required this.holdings});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final visibleHoldings = holdings
        .where((h) => h.currentPrice != null && h.currentPrice! > 0)
        .toList();

    if (visibleHoldings.isEmpty) {
      return AppPanel(
        child: Text(
          holdings.isEmpty
              ? 'Aucune position. Utilisez "Ajouter" pour commencer.'
              : 'Positions sans donnees de marche disponibles.',
          style: TextStyle(color: textSecondary),
        ),
      );
    }

    final sorted = [...visibleHoldings]
      ..sort((a, b) => (b.totalValue ?? 0).compareTo(a.totalValue ?? 0));

    return AppPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final holding in sorted.take(10))
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                  ),
                ),
              ),
              child: Row(
                children: [
                  AssetLogo(
                    symbol: holding.symbol,
                    assetType: holding.assetType,
                    size: 26,
                    borderRadius: 999,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          holding.symbol,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          holding.name ?? '--',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: Text(
                      holding.currentPrice != null
                          ? AppFormats.currency.format(holding.currentPrice)
                          : '--',
                      textAlign: TextAlign.end,
                      style: GoogleFonts.robotoMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  SizedBox(
                    width: 110,
                    child: Text(
                      holding.totalValue != null
                          ? AppFormats.currency.format(holding.totalValue)
                          : '--',
                      textAlign: TextAlign.end,
                      style: GoogleFonts.robotoMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _PnlBadge(percent: holding.changePercent),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PnlBadge extends StatelessWidget {
  final double? percent;

  const _PnlBadge({required this.percent});

  @override
  Widget build(BuildContext context) {
    final has = percent != null;
    final value = percent ?? 0;
    final up = value >= 0;
    final color = up ? AppColors.success : AppColors.danger;

    return Container(
      width: 72,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: (has ? color : AppColors.textSecondaryLight).withValues(
          alpha: 0.1,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        has ? '${up ? '+' : ''}${value.toStringAsFixed(2)}%' : '--',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: has ? color : AppColors.textSecondaryLight,
        ),
      ),
    );
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
    final textPrimary = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return AppPanel(
      padding: const EdgeInsets.all(AppSpacing.md),
      variant: AppPanelVariant.elevated,
      child: SizedBox(
        width: 170,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 15, color: color),
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
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
