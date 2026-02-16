import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/portfolio/models/holding.dart';
import 'package:solver/features/portfolio/models/watchlist_item.dart';
import 'package:solver/features/portfolio/providers/portfolio_provider.dart';
import 'package:solver/features/portfolio/providers/price_history_provider.dart';
import 'package:solver/features/portfolio/providers/watchlist_provider.dart';
import 'package:solver/features/portfolio/views/market_tab.dart';
import 'package:solver/features/portfolio/views/positions_tab.dart';
import 'package:solver/features/portfolio/widgets/add_holding_dialog.dart';
import 'package:solver/features/portfolio/widgets/add_watchlist_dialog.dart';
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
      ref.invalidate(watchlistProvider);
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
    ref.invalidate(watchlistProvider);
    await Future.wait([
      ref.read(portfolioProvider.future),
      ref.read(watchlistProvider.future),
    ]);
  }

  Future<void> _openAddHoldingDialog() async {
    final created = await showAddHoldingDialog(context);
    if (!mounted || !created) return;
    _showSuccess('Position ajoutee');
  }

  Future<void> _openAddWatchlistDialog() async {
    final created = await showAddWatchlistDialog(context);
    if (!mounted || !created) return;
    _showSuccess('Symbole ajoute a la watchlist');
  }

  @override
  Widget build(BuildContext context) {
    final portfolioAsync = ref.watch(portfolioProvider);
    final watchlistAsync = ref.watch(watchlistProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final portfolioData = portfolioAsync.valueOrNull;
    final holdings = portfolioData?.holdings ?? const <Holding>[];
    final watchlistItems =
        watchlistAsync.valueOrNull ?? const <WatchlistItem>[];

    final symbols = <String>{
      ...holdings.map((h) => h.symbol),
      ...watchlistItems.map((w) => w.symbol),
    }.toList()
      ..sort();

    final sparklineAsync = ref.watch(
      sparklineBatchProvider(SparklineBatchRequest(symbols: symbols)),
    );

    final sparklineBySymbol = <String, List<double>>{};
    final sparklineMap = sparklineAsync.valueOrNull ?? const {};
    for (final entry in sparklineMap.entries) {
      sparklineBySymbol[entry.key] =
          entry.value.map((p) => p.close).toList();
    }

    final hasBlockingError =
        portfolioData == null &&
        (portfolioAsync.hasError || watchlistAsync.hasError);

    if (hasBlockingError) {
      final error = portfolioAsync.error ?? watchlistAsync.error;
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

    final anyStale =
        holdings.any((h) => h.isStale) ||
        watchlistItems.any((w) => w.isStale);

    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return Padding(
      padding: AppSpacing.paddingPage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: title + tabs + actions
          Row(
            children: [
              Text(
                'Portfolio',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.xl),
              // Tab bar
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceDark
                      : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color:
                        isDark ? AppColors.borderDark : AppColors.borderLight,
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
                  labelPadding: const EdgeInsets.symmetric(horizontal: 16),
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
          const SizedBox(height: AppSpacing.lg),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                PositionsTab(
                  summary: portfolioData.summary,
                  holdings: holdings,
                  watchlistItems: watchlistItems,
                  sparklineBySymbol: sparklineBySymbol,
                  onAddHolding: _openAddHoldingDialog,
                  onAddWatchlist: _openAddWatchlistDialog,
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
