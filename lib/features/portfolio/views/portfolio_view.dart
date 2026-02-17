import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/portfolio/models/holding.dart';
import 'package:solver/features/portfolio/models/trending_stock.dart';
import 'package:solver/features/portfolio/providers/portfolio_provider.dart';
import 'package:solver/features/portfolio/providers/price_history_provider.dart';
import 'package:solver/features/portfolio/providers/trending_provider.dart';
import 'package:solver/features/portfolio/views/market_tab.dart';
import 'package:solver/features/portfolio/views/positions_tab.dart';
import 'package:solver/features/portfolio/widgets/add_holding_dialog.dart';
import 'package:solver/features/portfolio/widgets/asset_logo.dart';
import 'package:solver/shared/widgets/app_panel.dart';

class PortfolioView extends ConsumerStatefulWidget {
  const PortfolioView({super.key});

  @override
  ConsumerState<PortfolioView> createState() => _PortfolioViewState();
}

class _PortfolioViewState extends ConsumerState<PortfolioView>
    with SingleTickerProviderStateMixin {
  Timer? _refreshTimer;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      ref.invalidate(portfolioProvider);
      ref.invalidate(trendingProvider);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    ref.invalidate(portfolioProvider);
    ref.invalidate(trendingProvider);
    await Future.wait([
      ref.read(portfolioProvider.future),
      ref.read(trendingProvider.future),
    ]);
  }

  Future<void> _openAddHoldingDialog() async {
    final created = await showAddHoldingDialog(context);
    if (!mounted || !created) return;
    _showSuccess('Position ajoutee');
  }

  @override
  Widget build(BuildContext context) {
    final portfolioAsync = ref.watch(portfolioProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final portfolioData = portfolioAsync.valueOrNull;
    final holdings = portfolioData?.holdings ?? const <Holding>[];

    final symbols = <String>{...holdings.map((h) => h.symbol)}.toList()..sort();

    final sparklineAsync = ref.watch(
      sparklineBatchProvider(SparklineBatchRequest(symbols: symbols)),
    );

    final sparklineBySymbol = <String, List<double>>{};
    final sparklineMap = sparklineAsync.valueOrNull ?? const {};
    for (final entry in sparklineMap.entries) {
      sparklineBySymbol[entry.key] = entry.value.map((p) => p.close).toList();
    }

    final hasBlockingError = portfolioData == null && portfolioAsync.hasError;

    if (hasBlockingError) {
      final error = portfolioAsync.error;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Erreur: $error', textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: _refreshData,
                child: const Text('Reessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (portfolioData == null) {
      return const _LoadingView();
    }

    final anyStale = holdings.any((h) => h.isStale);

    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final textPrimary = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.xxl, 0, AppSpacing.xxl, 0),
          child: _MarketTickerTape(),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              AppSpacing.sm,
              AppSpacing.xxl,
              AppSpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: title + tabs + actions
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Portfolio',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'Actions, ETFs et crypto en vue unifiee',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(width: AppSpacing.xl),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceDark
                            : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight,
                        ),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                        labelColor: AppColors.primary,
                        unselectedLabelColor: textSecondary,
                        labelStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        dividerHeight: 0,
                        padding: const EdgeInsets.all(2),
                        labelPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                        tabs: const [
                          Tab(text: 'Mes Positions', height: 32),
                          Tab(text: 'Marche', height: 32),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Rafraichir',
                      onPressed: _refreshData,
                      icon: const Icon(Icons.refresh, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    ElevatedButton.icon(
                      onPressed: _openAddHoldingDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Ajouter'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      PositionsTab(
                        summary: portfolioData.summary,
                        holdings: holdings,
                        sparklineBySymbol: sparklineBySymbol,
                        onAddHolding: _openAddHoldingDialog,
                        onRefresh: _refreshData,
                      ),
                      const MarketTab(),
                    ],
                  ),
                ),

                // Delayed badge
                const SizedBox(height: AppSpacing.sm),
                _DelayedBadge(showWarning: anyStale),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _MarketTickerTape extends ConsumerStatefulWidget {
  const _MarketTickerTape();

  @override
  ConsumerState<_MarketTickerTape> createState() => _MarketTickerTapeState();
}

class _MarketTickerTapeState extends ConsumerState<_MarketTickerTape> {
  late final ScrollController _controller;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    _autoTimer = Timer.periodic(const Duration(milliseconds: 35), (_) {
      if (!_controller.hasClients) return;
      final max = _controller.position.maxScrollExtent;
      if (max <= 0) return;
      final resetPoint = max / 2;
      final next = _controller.offset + 1.2;
      if (next >= resetPoint) {
        _controller.jumpTo(0);
      } else {
        _controller.jumpTo(next);
      }
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  List<TrendingStock> _buildTapeItems(MarketTrendingData market) {
    final unique = <String, TrendingStock>{};
    for (final item in [...market.stocks, ...market.crypto]) {
      final symbol = item.symbol.trim().toUpperCase();
      if (symbol.isEmpty) continue;
      unique.putIfAbsent(symbol, () => item);
    }

    for (final fallback in _tickerFallbackAssets) {
      final symbol = fallback.symbol.trim().toUpperCase();
      unique.putIfAbsent(symbol, () => fallback);
      if (unique.length >= 20) break;
    }

    final items = unique.values.take(20).toList();
    if (items.length < 20 && items.isNotEmpty) {
      final seed = List<TrendingStock>.from(items);
      var i = 0;
      while (items.length < 20) {
        items.add(seed[i % seed.length]);
        i++;
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final trendingAsync = ref.watch(trendingProvider);

    return trendingAsync.when(
      loading: () => const SizedBox(
        height: 44,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (market) {
        final items = _buildTapeItems(market);
        if (items.isEmpty) return const SizedBox.shrink();
        final loopedItems = [...items, ...items];

        return AppPanel(
          variant: AppPanelVariant.elevated,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: SizedBox(
            height: 44,
            child: ListView.separated(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: loopedItems.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, index) {
                final item = loopedItems[index];
                final pct = item.changePercent ?? 0;
                final up = pct >= 0;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Row(
                    children: [
                      AssetLogo(
                        symbol: item.symbol,
                        assetType: item.assetType,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.symbol,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.price == null
                            ? '--'
                            : item.price!.toStringAsFixed(2),
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.changePercent == null
                            ? '--'
                            : '${up ? '+' : ''}${pct.toStringAsFixed(2)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: up ? AppColors.success : AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

const List<TrendingStock> _tickerFallbackAssets = [
  TrendingStock(
    symbol: 'AAPL',
    name: 'Apple Inc',
    price: null,
    changePercent: null,
    currency: 'USD',
    isStale: true,
    assetType: 'stock',
  ),
  TrendingStock(
    symbol: 'MSFT',
    name: 'Microsoft Corp',
    price: null,
    changePercent: null,
    currency: 'USD',
    isStale: true,
    assetType: 'stock',
  ),
  TrendingStock(
    symbol: 'NVDA',
    name: 'NVIDIA Corp',
    price: null,
    changePercent: null,
    currency: 'USD',
    isStale: true,
    assetType: 'stock',
  ),
  TrendingStock(
    symbol: 'AMZN',
    name: 'Amazon.com Inc',
    price: null,
    changePercent: null,
    currency: 'USD',
    isStale: true,
    assetType: 'stock',
  ),
  TrendingStock(
    symbol: 'GOOGL',
    name: 'Alphabet Inc',
    price: null,
    changePercent: null,
    currency: 'USD',
    isStale: true,
    assetType: 'stock',
  ),
  TrendingStock(
    symbol: 'META',
    name: 'Meta Platforms',
    price: null,
    changePercent: null,
    currency: 'USD',
    isStale: true,
    assetType: 'stock',
  ),
  TrendingStock(
    symbol: 'TSLA',
    name: 'Tesla Inc',
    price: null,
    changePercent: null,
    currency: 'USD',
    isStale: true,
    assetType: 'stock',
  ),
  TrendingStock(
    symbol: 'NFLX',
    name: 'Netflix Inc',
    price: null,
    changePercent: null,
    currency: 'USD',
    isStale: true,
    assetType: 'stock',
  ),
  TrendingStock(
    symbol: 'AMD',
    name: 'AMD',
    price: null,
    changePercent: null,
    currency: 'USD',
    isStale: true,
    assetType: 'stock',
  ),
  TrendingStock(
    symbol: 'INTC',
    name: 'Intel Corp',
    price: null,
    changePercent: null,
    currency: 'USD',
    isStale: true,
    assetType: 'stock',
  ),
  TrendingStock(
    symbol: 'JPM',
    name: 'JPMorgan Chase',
    price: null,
    changePercent: null,
    currency: 'USD',
    isStale: true,
    assetType: 'stock',
  ),
  TrendingStock(
    symbol: 'V',
    name: 'Visa Inc',
    price: null,
    changePercent: null,
    currency: 'USD',
    isStale: true,
    assetType: 'stock',
  ),
  TrendingStock(
    symbol: 'BTC/USD',
    name: 'Bitcoin',
    price: null,
    changePercent: null,
    currency: 'USD',
    isStale: true,
    assetType: 'crypto',
  ),
  TrendingStock(
    symbol: 'ETH/USD',
    name: 'Ethereum',
    price: null,
    changePercent: null,
    currency: 'USD',
    isStale: true,
    assetType: 'crypto',
  ),
  TrendingStock(
    symbol: 'SOL/USD',
    name: 'Solana',
    price: null,
    changePercent: null,
    currency: 'USD',
    isStale: true,
    assetType: 'crypto',
  ),
  TrendingStock(
    symbol: 'BNB/USD',
    name: 'BNB',
    price: null,
    changePercent: null,
    currency: 'USD',
    isStale: true,
    assetType: 'crypto',
  ),
  TrendingStock(
    symbol: 'XRP/USD',
    name: 'XRP',
    price: null,
    changePercent: null,
    currency: 'USD',
    isStale: true,
    assetType: 'crypto',
  ),
  TrendingStock(
    symbol: 'ADA/USD',
    name: 'Cardano',
    price: null,
    changePercent: null,
    currency: 'USD',
    isStale: true,
    assetType: 'crypto',
  ),
  TrendingStock(
    symbol: 'DOGE/USD',
    name: 'Dogecoin',
    price: null,
    changePercent: null,
    currency: 'USD',
    isStale: true,
    assetType: 'crypto',
  ),
  TrendingStock(
    symbol: 'AVAX/USD',
    name: 'Avalanche',
    price: null,
    changePercent: null,
    currency: 'USD',
    isStale: true,
    assetType: 'crypto',
  ),
];

class _DelayedBadge extends StatelessWidget {
  final bool showWarning;

  const _DelayedBadge({required this.showWarning});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: (showWarning ? AppColors.warning : AppColors.info)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.r16),
          ),
          child: Text(
            'Donnees retardees 15 min',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: showWarning ? AppColors.warning : AppColors.info,
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.paddingPage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _LoadingBox(height: 44),
          SizedBox(height: AppSpacing.lg),
          _LoadingBox(height: 100),
          SizedBox(height: AppSpacing.lg),
          Expanded(child: _LoadingBox()),
        ],
      ),
    );
  }
}

class _LoadingBox extends StatelessWidget {
  final double? height;

  const _LoadingBox({this.height});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppPanel(
      child: SizedBox(
        height: height,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(AppRadius.r8),
          ),
        ),
      ),
    );
  }
}
