import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/portfolio/models/holding.dart';
import 'package:solver/features/portfolio/models/portfolio_summary.dart';
import 'package:solver/features/portfolio/models/watchlist_item.dart';
import 'package:solver/features/portfolio/providers/selected_asset_provider.dart';
import 'package:solver/features/portfolio/widgets/asset_detail_inline.dart';
import 'package:solver/features/portfolio/widgets/asset_row.dart';
import 'package:solver/features/portfolio/widgets/asset_sidebar.dart';
import 'package:solver/features/portfolio/widgets/portfolio_dashboard.dart';

class PositionsTab extends ConsumerWidget {
  final PortfolioSummary summary;
  final List<Holding> holdings;
  final List<WatchlistItem> watchlistItems;
  final Map<String, List<double>> sparklineBySymbol;
  final VoidCallback onAddHolding;
  final VoidCallback onAddWatchlist;
  final Future<void> Function() onRefresh;

  const PositionsTab({
    super.key,
    required this.summary,
    required this.holdings,
    required this.watchlistItems,
    required this.sparklineBySymbol,
    required this.onAddHolding,
    required this.onAddWatchlist,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedAssetProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > AppBreakpoints.desktop;

        if (isDesktop) {
          return _DesktopLayout(
            summary: summary,
            holdings: holdings,
            watchlistItems: watchlistItems,
            sparklineBySymbol: sparklineBySymbol,
            selected: selected,
            onAddHolding: onAddHolding,
            onAddWatchlist: onAddWatchlist,
          );
        }

        return _MobileLayout(
          summary: summary,
          holdings: holdings,
          watchlistItems: watchlistItems,
          sparklineBySymbol: sparklineBySymbol,
          selected: selected,
          onAddHolding: onAddHolding,
          onAddWatchlist: onAddWatchlist,
          onRefresh: onRefresh,
        );
      },
    );
  }
}

class _DesktopLayout extends ConsumerWidget {
  final PortfolioSummary summary;
  final List<Holding> holdings;
  final List<WatchlistItem> watchlistItems;
  final Map<String, List<double>> sparklineBySymbol;
  final SelectedAsset? selected;
  final VoidCallback onAddHolding;
  final VoidCallback onAddWatchlist;

  const _DesktopLayout({
    required this.summary,
    required this.holdings,
    required this.watchlistItems,
    required this.sparklineBySymbol,
    required this.selected,
    required this.onAddHolding,
    required this.onAddWatchlist,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 300,
          child: AssetSidebar(
            summary: summary,
            holdings: holdings,
            watchlistItems: watchlistItems,
            sparklineBySymbol: sparklineBySymbol,
            onAddHolding: onAddHolding,
            onAddWatchlist: onAddWatchlist,
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: selected != null
              ? AssetDetailInline(
                  key: ValueKey(selected!.symbol),
                  symbol: selected!.symbol,
                  holding: selected!.holding,
                  watchlistItem: selected!.watchlistItem,
                  onClose: () {
                    ref.read(selectedAssetProvider.notifier).state = null;
                  },
                )
              : PortfolioDashboard(
                  summary: summary,
                  holdings: holdings,
                ),
        ),
      ],
    );
  }
}

class _MobileLayout extends ConsumerWidget {
  final PortfolioSummary summary;
  final List<Holding> holdings;
  final List<WatchlistItem> watchlistItems;
  final Map<String, List<double>> sparklineBySymbol;
  final SelectedAsset? selected;
  final VoidCallback onAddHolding;
  final VoidCallback onAddWatchlist;
  final Future<void> Function() onRefresh;

  const _MobileLayout({
    required this.summary,
    required this.holdings,
    required this.watchlistItems,
    required this.sparklineBySymbol,
    required this.selected,
    required this.onAddHolding,
    required this.onAddWatchlist,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If a stock is selected on mobile, show full-screen detail
    if (selected != null) {
      return AssetDetailInline(
        key: ValueKey(selected!.symbol),
        symbol: selected!.symbol,
        holding: selected!.holding,
        watchlistItem: selected!.watchlistItem,
        onClose: () {
          ref.read(selectedAssetProvider.notifier).state = null;
        },
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        children: [
          // Positions header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              AppSpacing.sm,
              AppSpacing.xs,
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
                  child: Icon(Icons.add, size: 18, color: AppColors.primary),
                ),
              ],
            ),
          ),
          ...holdings.map(
            (h) => AssetRow(
              symbol: h.symbol,
              name: h.name,
              price: h.currentPrice,
              changePercent: h.changePercent,
              sparklineData: sparklineBySymbol[h.symbol],
              onTap: () {
                ref.read(selectedAssetProvider.notifier).state =
                    SelectedAsset(symbol: h.symbol, holding: h);
              },
            ),
          ),
          const Divider(height: AppSpacing.lg),

          // Watchlist header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              AppSpacing.xs,
              AppSpacing.xs,
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
                  child: Icon(Icons.add, size: 18, color: AppColors.primary),
                ),
              ],
            ),
          ),
          ...watchlistItems.map(
            (w) => AssetRow(
              symbol: w.symbol,
              name: w.name,
              price: w.currentPrice,
              changePercent: w.changePercent,
              sparklineData: sparklineBySymbol[w.symbol],
              onTap: () {
                ref.read(selectedAssetProvider.notifier).state =
                    SelectedAsset(symbol: w.symbol, watchlistItem: w);
              },
            ),
          ),
          if (holdings.isEmpty && watchlistItems.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: Text(
                  'Aucune position. Ajoutez votre premier actif.',
                  style: TextStyle(color: textSecondary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
