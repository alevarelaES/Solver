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

const Set<String> _knownStockSymbols = {
  'AAPL',
  'MSFT',
  'NVDA',
  'AMZN',
  'GOOGL',
  'META',
  'TSLA',
  'NFLX',
  'AMD',
  'INTC',
  'JPM',
  'V',
  'JNJ',
  'WMT',
  'DIS',
  'PYPL',
  'BA',
  'CRM',
  'UBER',
  'PG',
};

const Set<String> _knownEtfSymbols = {
  'SPY',
  'QQQ',
  'VTI',
  'VOO',
  'IWM',
  'DIA',
  'XLF',
  'XLE',
  'XLK',
  'ARKK',
  'GLD',
  'SLV',
};

const Set<String> _knownCryptoSymbols = {
  'BTC/USD',
  'ETH/USD',
  'SOL/USD',
  'BNB/USD',
  'XRP/USD',
  'ADA/USD',
  'DOGE/USD',
  'AVAX/USD',
  'DOT/USD',
  'LINK/USD',
};

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
    final trending = ref.watch(trendingProvider).valueOrNull;
    final preferredSymbols = <String>{
      ..._knownStockSymbols,
      ..._knownEtfSymbols,
      ..._knownCryptoSymbols,
      ...?trending?.stocks.map((s) => s.symbol.trim().toUpperCase()),
      ...?trending?.crypto.map((s) => s.symbol.trim().toUpperCase()),
    };
    final cleanedHoldings = holdings
        .where((holding) => _isKnownHolding(holding, preferredSymbols))
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > AppBreakpoints.desktop;

        if (isDesktop) {
          return _DesktopLayout(
            summary: summary,
            holdings: cleanedHoldings,
            sparklineBySymbol: sparklineBySymbol,
            selected: selected,
            onAddHolding: onAddHolding,
          );
        }

        return _MobileLayout(
          summary: summary,
          holdings: cleanedHoldings,
          sparklineBySymbol: sparklineBySymbol,
          selected: selected,
          onAddHolding: onAddHolding,
          onRefresh: onRefresh,
        );
      },
    );
  }
}

class _DesktopLayout extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveSelected = _resolveSelected(ref);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 320,
          child: AssetSidebar(
            summary: summary,
            holdings: holdings,
            sparklineBySymbol: sparklineBySymbol,
            onAddHolding: onAddHolding,
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: effectiveSelected != null
              ? AssetDetailInline(
                  key: ValueKey(effectiveSelected.symbol),
                  symbol: effectiveSelected.symbol,
                  holding: effectiveSelected.holding,
                  watchlistItem: effectiveSelected.watchlistItem,
                  onClose: () {
                    ref.read(selectedAssetProvider.notifier).state = null;
                  },
                )
              : PortfolioDashboard(summary: summary, holdings: holdings),
        ),
      ],
    );
  }

  SelectedAsset? _resolveSelected(WidgetRef ref) {
    if (selected != null) {
      final selectedSymbol = selected!.symbol.trim().toUpperCase();
      final inCleanedHoldings = holdings.any(
        (h) => h.symbol.trim().toUpperCase() == selectedSymbol,
      );
      if (inCleanedHoldings || _isKnownSymbol(selectedSymbol)) {
        return selected;
      }
    }
    if (holdings.isNotEmpty) {
      final first = holdings.first;
      return SelectedAsset(symbol: first.symbol, holding: first);
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
          ...holdings.map(
            (h) => AssetRow(
              symbol: h.symbol,
              name: h.name,
              assetType: h.assetType,
              price: h.currentPrice,
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
          if (holdings.isEmpty)
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

bool _isKnownHolding(Holding holding, Set<String> preferredSymbols) {
  final symbol = holding.symbol.trim().toUpperCase();
  final price = holding.currentPrice ?? 0;
  if (symbol.isEmpty || price <= 0) return false;

  if (preferredSymbols.contains(symbol)) return true;

  if (symbol.contains('/')) {
    return _knownCryptoSymbols.contains(symbol);
  }

  return false;
}

bool _isKnownSymbol(String symbol) {
  if (_knownStockSymbols.contains(symbol)) return true;
  if (_knownEtfSymbols.contains(symbol)) return true;
  if (_knownCryptoSymbols.contains(symbol)) return true;
  return false;
}
