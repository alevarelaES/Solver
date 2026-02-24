import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/settings/currency_settings_provider.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/portfolio/models/holding.dart';
import 'package:solver/features/portfolio/models/portfolio_summary.dart';
import 'package:solver/features/portfolio/widgets/asset_logo.dart';
import 'package:solver/shared/widgets/app_panel.dart';

class InvestmentsTab extends ConsumerWidget {
  final PortfolioSummary summary;
  final List<Holding> holdings;

  const InvestmentsTab({
    super.key,
    required this.summary,
    required this.holdings,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appCurrencyProvider);
    final visible = holdings
        .where((h) => h.currentPrice != null && h.currentPrice! > 0)
        .toList();
    final tracked = visible
        .where((h) => h.averageBuyPrice != null && h.averageBuyPrice! > 0)
        .toList();
    final excluded = visible.length - tracked.length;
    // Totaux convertis vers devise active
    final investedTotal = tracked.fold<double>(
      0,
      (sum, h) => sum + AppFormats.convertFromCurrency(h.averageBuyPrice! * h.quantity, h.currency),
    );
    final valueTotal = tracked.fold<double>(
      0,
      (sum, h) => sum + AppFormats.convertFromCurrency(
          h.totalValue ?? (h.currentPrice ?? 0) * h.quantity, h.currency),
    );
    final gainTotal = valueTotal - investedTotal;
    final gainPercent = investedTotal > 0
        ? (gainTotal / investedTotal) * 100
        : 0.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          AppPanel(
            variant: AppPanelVariant.subtle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MON INVESTISSEMENT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Total investi réel : ${AppFormats.currency.format(investedTotal)} (${AppFormats.currencyCode})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  excluded > 0
                      ? '$excluded position(s) sans investissement defini sont exclues des stats.'
                      : 'Ces stats reflètent uniquement tes investissements réels.',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _StatCard(
                label: 'Investi total',
                value: AppFormats.currency.format(investedTotal),
                color: AppColors.info,
              ),
              _StatCard(
                label: 'Valeur actuelle',
                value: AppFormats.currency.format(valueTotal),
                color: AppColors.primary,
              ),
              _StatCard(
                label: 'Gain / Perte',
                value: AppFormats.currency.format(gainTotal),
                // gainTotal est déjà en devise active
                color: gainTotal >= 0 ? AppColors.success : AppColors.danger,
              ),
              _StatCard(
                label: 'Performance',
                value:
                    '${gainPercent >= 0 ? '+' : ''}${gainPercent.toStringAsFixed(2)}%',
                color: gainPercent >= 0 ? AppColors.success : AppColors.danger,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Mes lignes',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (tracked.isEmpty)
            AppPanel(
              child: Text(
                holdings.isEmpty
                    ? 'Aucune position. Ajoute ton premier investissement.'
                    : 'Aucune ligne avec investissement defini.',
                style: TextStyle(color: textSecondary),
              ),
            )
          else
            Column(
              children: tracked
                  .map((holding) => _InvestmentRow(holding: holding))
                  .toList(),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      variant: AppPanelVariant.elevated,
      child: SizedBox(
        width: 210,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.robotoMono(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvestmentRow extends ConsumerWidget {
  final Holding holding;

  const _InvestmentRow({required this.holding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appCurrencyProvider);
    final rawInvested = holding.averageBuyPrice == null
        ? null
        : holding.averageBuyPrice! * holding.quantity;
    final rawCurrent =
        holding.totalValue ?? (holding.currentPrice ?? 0) * holding.quantity;
    final rawGain =
        holding.totalGainLoss ?? (rawInvested == null ? null : rawCurrent - rawInvested);
    // Convertir vers devise active
    final invested = rawInvested == null ? null : AppFormats.convertFromCurrency(rawInvested, holding.currency);
    final current = AppFormats.convertFromCurrency(rawCurrent, holding.currency);
    final gain = rawGain == null ? null : AppFormats.convertFromCurrency(rawGain, holding.currency);
    final perf =
        holding.totalGainLossPercent ??
        (rawInvested != null && rawInvested > 0 ? (rawGain! / rawInvested) * 100 : null);
    final up = (gain ?? 0) >= 0;
    final perfColor = up ? AppColors.success : AppColors.danger;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppPanel(
        variant: AppPanelVariant.elevated,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            AssetLogo(
              symbol: holding.symbol,
              assetType: holding.assetType,
              size: 32,
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
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    holding.name ?? '--',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ],
              ),
            ),
            _ValueBlock(
              label: 'Investi',
              value: invested == null ? '--' : AppFormats.currency.format(invested),
            ),
            const SizedBox(width: AppSpacing.md),
            _ValueBlock(
              label: 'Valeur',
              value: AppFormats.currency.format(current),
            ),
            const SizedBox(width: AppSpacing.md),
            _ValueBlock(
              label: 'P/L',
              value: gain == null
                  ? '--'
                  : '${AppFormats.currency.format(gain)} (${perf == null ? '--' : '${up ? '+' : ''}${perf.toStringAsFixed(2)}%'})',
              valueColor: gain == null ? null : perfColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueBlock extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _ValueBlock({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: textSecondary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.robotoMono(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
