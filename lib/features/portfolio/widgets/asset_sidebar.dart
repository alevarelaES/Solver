import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/portfolio/models/holding.dart';
import 'package:solver/features/portfolio/models/portfolio_summary.dart';
import 'package:solver/features/portfolio/models/watchlist_item.dart';
import 'package:solver/features/portfolio/providers/selected_asset_provider.dart';
import 'package:solver/features/portfolio/widgets/asset_row.dart';
import 'package:solver/shared/widgets/app_panel.dart';

class AssetSidebar extends ConsumerWidget {
  final PortfolioSummary summary;
  final List<Holding> holdings;
  final List<WatchlistItem> watchlistItems;
  final Map<String, List<double>> sparklineBySymbol;
  final VoidCallback onAddHolding;
  final VoidCallback onAddWatchlist;

  const AssetSidebar({
    super.key,
    required this.summary,
    required this.holdings,
    required this.watchlistItems,
    required this.sparklineBySymbol,
    required this.onAddHolding,
    required this.onAddWatchlist,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final selected = ref.watch(selectedAssetProvider);

    return AppPanel(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mini summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Valeur totale',
                        style: TextStyle(fontSize: 10, color: textSecondary),
                      ),
                      Text(
                        AppFormats.currency.format(summary.totalValue),
                        style: GoogleFonts.robotoMono(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (summary.totalGainLoss >= 0
                            ? AppColors.success
                            : AppColors.danger)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Text(
                    '${summary.totalGainLoss >= 0 ? '+' : ''}${summary.totalGainLossPercent.toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: summary.totalGainLoss >= 0
                          ? AppColors.success
                          : AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),

          // Holdings section
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Text(
                  'POSITIONS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: textSecondary,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: onAddHolding,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.add,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: holdings.isEmpty
                ? Center(
                    child: Text(
                      'Aucune position',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  )
                : ListView.builder(
                    itemCount: holdings.length,
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) {
                      final h = holdings[index];
                      return AssetRow(
                        symbol: h.symbol,
                        name: h.name,
                        price: h.currentPrice,
                        changePercent: h.changePercent,
                        sparklineData: sparklineBySymbol[h.symbol],
                        isSelected: selected?.symbol == h.symbol,
                        onTap: () {
                          ref.read(selectedAssetProvider.notifier).state =
                              SelectedAsset(symbol: h.symbol, holding: h);
                        },
                      );
                    },
                  ),
          ),

          const Divider(height: 1),

          // Watchlist section
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Text(
                  'WATCHLIST',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: textSecondary,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: onAddWatchlist,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.add,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: watchlistItems.isEmpty
                ? Center(
                    child: Text(
                      'Watchlist vide',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  )
                : ListView.builder(
                    itemCount: watchlistItems.length,
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) {
                      final w = watchlistItems[index];
                      return AssetRow(
                        symbol: w.symbol,
                        name: w.name,
                        price: w.currentPrice,
                        changePercent: w.changePercent,
                        sparklineData: sparklineBySymbol[w.symbol],
                        isSelected: selected?.symbol == w.symbol,
                        onTap: () {
                          ref.read(selectedAssetProvider.notifier).state =
                              SelectedAsset(
                            symbol: w.symbol,
                            watchlistItem: w,
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
