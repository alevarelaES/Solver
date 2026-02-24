import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/portfolio/models/holding.dart';
import 'package:solver/features/portfolio/models/portfolio_summary.dart';
import 'package:solver/features/portfolio/providers/selected_asset_provider.dart';
import 'package:solver/features/portfolio/providers/trending_provider.dart';
import 'package:solver/features/portfolio/widgets/asset_detail_inline.dart';
import 'package:solver/features/portfolio/widgets/asset_row.dart';
import 'package:solver/features/portfolio/widgets/asset_sidebar.dart';
import 'package:solver/features/portfolio/widgets/portfolio_dashboard.dart';

class PositionsTab extends ConsumerWidget {
  final PortfolioSummary summary;
  final List<Holding> holdings;
  final Map<String, List<double>> sparklineBySymbol;
  final VoidCallback onAddHolding;
  final Future<void> Function() onRefresh;

  const PositionsTab({
    super.key,
    required this.summary,
    required this.holdings,
    required this.sparklineBySymbol,
    required this.onAddHolding,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedAssetProvider);
    final investedHoldings = holdings.where(_isInvested).toList();
    final investedSummary = _buildSummaryFromInvested(investedHoldings);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > AppBreakpoints.desktop;

        if (isDesktop) {
          return _DesktopLayout(
            summary: investedSummary,
            holdings: investedHoldings,
            sparklineBySymbol: sparklineBySymbol,
            selected: selected,
            onAddHolding: onAddHolding,
          );
        }

        return _MobileLayout(
          summary: investedSummary,
          holdings: investedHoldings,
          sparklineBySymbol: sparklineBySymbol,
          selected: selected,
          onAddHolding: onAddHolding,
          onRefresh: onRefresh,
        );
      },
    );
  }

  bool _isInvested(Holding holding) =>
      holding.quantity > 0 &&
      holding.averageBuyPrice != null &&
      holding.averageBuyPrice! > 0;

  PortfolioSummary _buildSummaryFromInvested(List<Holding> investedHoldings) {
    final totalInvested = investedHoldings.fold<double>(
      0,
      (sum, h) => sum + (h.averageBuyPrice! * h.quantity),
    );
    final totalValue = investedHoldings.fold<double>(
      0,
      (sum, h) => sum + (h.totalValue ?? (h.currentPrice ?? 0) * h.quantity),
    );
    final totalGainLoss = totalValue - totalInvested;
    final totalGainLossPercent = totalInvested > 0
        ? (totalGainLoss / totalInvested) * 100
        : 0.0;

    return PortfolioSummary(
      totalValue: totalValue,
      totalInvested: totalInvested,
      totalGainLoss: totalGainLoss,
      totalGainLossPercent: totalGainLossPercent,
      holdingsCount: investedHoldings.length,
    );
  }
}

class _DesktopLayout extends ConsumerStatefulWidget {
  final PortfolioSummary summary;
  final List<Holding> holdings;
  final Map<String, List<double>> sparklineBySymbol;
  final SelectedAsset? selected;
  final VoidCallback onAddHolding;

  const _DesktopLayout({
    required this.summary,
    required this.holdings,
    required this.sparklineBySymbol,
    required this.selected,
    required this.onAddHolding,
  });

  @override
  ConsumerState<_DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends ConsumerState<_DesktopLayout> {
  bool _detailsDismissed = false;

  @override
  Widget build(BuildContext context) {
    final effectiveSelected = _resolveSelected();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactDesktop = constraints.maxWidth < 1380;
        final sidebarWidth = compactDesktop ? 292.0 : 320.0;
        final gap = compactDesktop ? AppSpacing.md : AppSpacing.lg;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: sidebarWidth,
              child: AssetSidebar(
                summary: widget.summary,
                holdings: widget.holdings,
                sparklineBySymbol: widget.sparklineBySymbol,
                onAddHolding: widget.onAddHolding,
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: effectiveSelected != null
                  ? AssetDetailInline(
                      key: ValueKey(effectiveSelected.symbol),
                      symbol: effectiveSelected.symbol,
                      holding: effectiveSelected.holding,
                      watchlistItem: effectiveSelected.watchlistItem,
                      onClose: () {
                        setState(() => _detailsDismissed = true);
                        ref.read(selectedAssetProvider.notifier).state = null;
                      },
                    )
                  : PortfolioDashboard(
                      summary: widget.summary,
                      holdings: widget.holdings,
                    ),
            ),
          ],
        );
      },
    );
  }

  SelectedAsset? _resolveSelected() {
    final selected = widget.selected;
    if (selected != null) {
      final holding = _holdingForSymbol(selected.symbol);
      if (holding != null) {
        return SelectedAsset(
          symbol: holding.symbol,
          holding: holding,
          watchlistItem: selected.watchlistItem,
        );
      }
      return selected;
    }

    if (_detailsDismissed) {
      return null;
    }

    final defaultHolding = _defaultHolding();
    if (defaultHolding == null) return null;
    return SelectedAsset(
      symbol: defaultHolding.symbol,
      holding: defaultHolding,
    );
  }

  Holding? _defaultHolding() {
    if (widget.holdings.isEmpty) return null;
    final candidates = [...widget.holdings];
    candidates.sort((a, b) => (b.totalValue ?? 0).compareTo(a.totalValue ?? 0));

    final withPrice = candidates
        .where((h) => h.currentPrice != null && h.currentPrice! > 0)
        .toList();
    if (withPrice.isNotEmpty) {
      return withPrice.first;
    }
    return candidates.first;
  }

  Holding? _holdingForSymbol(String symbol) {
    for (final holding in widget.holdings) {
      if (holding.symbol.toUpperCase() == symbol.toUpperCase()) {
        return holding;
      }
    }
    return null;
  }
}

class _MobileLayout extends ConsumerWidget {
  final PortfolioSummary summary;
  final List<Holding> holdings;
  final Map<String, List<double>> sparklineBySymbol;
  final SelectedAsset? selected;
  final VoidCallback onAddHolding;
  final Future<void> Function() onRefresh;

  const _MobileLayout({
    required this.summary,
    required this.holdings,
    required this.sparklineBySymbol,
    required this.selected,
    required this.onAddHolding,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayHoldings = holdings;

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
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final trendingAsync = ref.watch(trendingProvider);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        children: [
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
          ...displayHoldings.map(
            (h) => AssetRow(
              symbol: h.symbol,
              name: h.name,
              assetType: h.assetType,
              price: h.currentPrice,
              currency: h.currency,
              changePercent: h.changePercent,
              sparklineData: sparklineBySymbol[h.symbol],
              onTap: () {
                ref.read(selectedAssetProvider.notifier).state = SelectedAsset(
                  symbol: h.symbol,
                  holding: h,
                );
              },
            ),
          ),
          const Divider(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              AppSpacing.xs,
              AppSpacing.xs,
              AppSpacing.xs,
            ),
            child: Text(
              'TOP MARCHE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: textSecondary,
              ),
            ),
          ),
          trendingAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, _) => Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'Tendances indisponibles.',
                style: TextStyle(color: textSecondary),
              ),
            ),
            data: (market) {
              final popular = [
                ...market.stocks.where((s) => (s.price ?? 0) > 0).take(12),
                ...market.crypto.where((s) => (s.price ?? 0) > 0).take(8),
              ];
              return Column(
                children: popular
                    .map(
                      (stock) => AssetRow(
                        symbol: stock.symbol,
                        name: stock.name,
                        assetType: stock.assetType,
                        price: stock.price,
                        currency: stock.currency,
                        changePercent: stock.changePercent,
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
          if (displayHoldings.isEmpty)
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
