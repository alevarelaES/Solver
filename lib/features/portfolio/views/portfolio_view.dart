import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/portfolio/data/portfolio_trending_catalog.dart';
import 'package:solver/features/portfolio/models/holding.dart';
import 'package:solver/features/portfolio/models/trending_stock.dart';
import 'package:solver/features/portfolio/providers/portfolio_provider.dart';
import 'package:solver/features/portfolio/providers/price_history_provider.dart';
import 'package:solver/features/portfolio/providers/selected_asset_provider.dart';
import 'package:solver/features/portfolio/providers/trending_provider.dart';
import 'package:solver/features/portfolio/views/investments_tab.dart';
import 'package:solver/features/portfolio/views/market_tab.dart';
import 'package:solver/features/portfolio/views/positions_tab.dart';
import 'package:solver/features/portfolio/widgets/add_holding_dialog.dart';
import 'package:solver/features/portfolio/widgets/asset_logo.dart';
import 'package:solver/shared/widgets/app_panel.dart';
import 'package:solver/shared/widgets/page_header.dart';
import 'package:solver/shared/widgets/page_scaffold.dart';

part 'portfolio_view.ticker.part.dart';

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
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (_tabController.index != 1) {
        ref.read(selectedAssetProvider.notifier).state = null;
      }
    });
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
      return AppPageScaffold(
        scrollable: false,
        child: Center(
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
        ),
      );
    }

    if (portfolioData == null) {
      return const AppPageScaffold(scrollable: false, child: _LoadingView());
    }

    final anyStale = holdings.any((h) => h.isStale);

    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return AppPageScaffold(
      scrollable: false,
      maxWidth: 1480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MarketTickerTape(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.md),
                  AppPanel(
                    variant: AppPanelVariant.subtle,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: AppPageHeader(
                      title: 'Portfolio',
                      subtitle: 'Actions, ETFs et crypto en vue unifiee',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                      bottom: _PortfolioHeaderBottom(
                        tabController: _tabController,
                        isDark: isDark,
                        textSecondary: textSecondary,
                        showWarning: anyStale,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ListenableBuilder(
                    listenable: _tabController,
                    builder: (context, _) => switch (_tabController.index) {
                      0 => PositionsTab(
                          summary: portfolioData.summary,
                          holdings: holdings,
                          sparklineBySymbol: sparklineBySymbol,
                          onAddHolding: _openAddHoldingDialog,
                          onRefresh: _refreshData,
                        ),
                      1 => const MarketTab(),
                      _ => InvestmentsTab(
                          summary: portfolioData.summary,
                          holdings: holdings,
                        ),
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
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

class _PortfolioHeaderBottom extends StatelessWidget {
  final TabController tabController;
  final bool isDark;
  final Color textSecondary;
  final bool showWarning;

  const _PortfolioHeaderBottom({
    required this.tabController,
    required this.isDark,
    required this.textSecondary,
    required this.showWarning,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1100;

        final tabBar = Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: TabBar(
            controller: tabController,
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
            padding: const EdgeInsets.all(AppSpacing.s2),
            labelPadding: const EdgeInsets.symmetric(horizontal: 16),
            tabs: const [
              Tab(text: 'Mes Positions', height: 32),
              Tab(text: 'Marché', height: 32),
              Tab(text: 'Mon investissement', height: 32),
            ],
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(alignment: Alignment.centerLeft, child: tabBar),
              const SizedBox(height: AppSpacing.sm),
              _DelayedBadge(showWarning: showWarning),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: Align(alignment: Alignment.centerLeft, child: tabBar),
            ),
            const SizedBox(width: AppSpacing.md),
            _DelayedBadge(showWarning: showWarning),
          ],
        );
      },
    );
  }
}
