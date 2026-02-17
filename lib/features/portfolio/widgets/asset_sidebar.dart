import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/portfolio/models/holding.dart';
import 'package:solver/features/portfolio/models/portfolio_summary.dart';
import 'package:solver/features/portfolio/models/trending_stock.dart';
import 'package:solver/features/portfolio/providers/selected_asset_provider.dart';
import 'package:solver/features/portfolio/providers/trending_provider.dart';
import 'package:solver/features/portfolio/widgets/asset_row.dart';
import 'package:solver/shared/widgets/app_panel.dart';

class AssetSidebar extends ConsumerWidget {
  final PortfolioSummary summary;
  final List<Holding> holdings;
  final Map<String, List<double>> sparklineBySymbol;
  final VoidCallback onAddHolding;

  const AssetSidebar({
    super.key,
    required this.summary,
    required this.holdings,
    required this.sparklineBySymbol,
    required this.onAddHolding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final selected = ref.watch(selectedAssetProvider);
    final trendingAsync = ref.watch(trendingProvider);
    final validHoldings = holdings
        .where((h) => h.currentPrice != null && (h.currentPrice ?? 0) > 0)
        .toList();
    final extraPopular = () {
      final market = trendingAsync.valueOrNull;
      if (market == null) return <TrendingStock>[];
      final merged = [...market.stocks, ...market.crypto];
      final existingSymbols = validHoldings.map((h) => h.symbol).toSet();
      return merged
          .where(
            (s) => !existingSymbols.contains(s.symbol) && (s.price ?? 0) > 0,
          )
          .take(validHoldings.length < 6 ? 6 - validHoldings.length : 0)
          .toList();
    }();

    return AppPanel(
      variant: AppPanelVariant.elevated,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryCard(summary: summary),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text(
                'MES POSITIONS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: textSecondary,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onAddHolding,
                icon: const Icon(Icons.add, size: 16),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: ListView(
              children: [
                if (validHoldings.isEmpty && extraPopular.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    child: Text(
                      'Aucune position.',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  )
                else
                  ...validHoldings.map(
                    (h) => AssetRow(
                      symbol: h.symbol,
                      name: h.name,
                      assetType: h.assetType,
                      price: h.currentPrice,
                      changePercent: h.changePercent,
                      sparklineData: sparklineBySymbol[h.symbol],
                      isSelected: selected?.symbol == h.symbol,
                      onTap: () {
                        ref.read(selectedAssetProvider.notifier).state =
                            SelectedAsset(symbol: h.symbol, holding: h);
                      },
                    ),
                  ),
                if (extraPopular.isNotEmpty)
                  ...extraPopular.map(
                    (stock) => AssetRow(
                      symbol: stock.symbol,
                      name: stock.name,
                      assetType: stock.assetType,
                      price: stock.price,
                      changePercent: stock.changePercent,
                      isSelected: selected?.symbol == stock.symbol,
                      onTap: () {
                        ref.read(selectedAssetProvider.notifier).state =
                            SelectedAsset(symbol: stock.symbol);
                      },
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'TOP MARCHE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                trendingAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (_, _) => Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Text(
                      'Tendances indisponibles.',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ),
                  data: (market) {
                    final popular = [
                      ...market.stocks.where((s) => (s.price ?? 0) > 0).take(4),
                      ...market.crypto.where((s) => (s.price ?? 0) > 0).take(3),
                    ];
                    if (popular.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        child: Text(
                          'Aucune tendance.',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      );
                    }

                    return Column(
                      children: popular
                          .map(
                            (stock) => AssetRow(
                              symbol: stock.symbol,
                              name: stock.name,
                              assetType: stock.assetType,
                              price: stock.price,
                              changePercent: stock.changePercent,
                              isSelected: selected?.symbol == stock.symbol,
                              onTap: () {
                                ref.read(selectedAssetProvider.notifier).state =
                                    SelectedAsset(symbol: stock.symbol);
                              },
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final PortfolioSummary summary;

  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final up = summary.totalGainLoss >= 0;
    final color = up ? AppColors.success : AppColors.danger;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppPanel(
      variant: AppPanelVariant.elevated,
      backgroundColor: isDark
          ? const Color(0xFF1A2327)
          : const Color(0xFFF0F7EE),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PORTFOLIO',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppFormats.currency.format(summary.totalValue),
            style: GoogleFonts.robotoMono(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'P/L ${AppFormats.currency.format(summary.totalGainLoss)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  '${up ? '+' : ''}${summary.totalGainLossPercent.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
