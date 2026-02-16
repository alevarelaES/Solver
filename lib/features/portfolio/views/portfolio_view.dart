import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/portfolio/models/holding.dart';
import 'package:solver/features/portfolio/models/watchlist_item.dart';
import 'package:solver/features/portfolio/providers/portfolio_provider.dart';
import 'package:solver/features/portfolio/providers/price_history_provider.dart';
import 'package:solver/features/portfolio/providers/watchlist_provider.dart';
import 'package:solver/features/portfolio/views/asset_detail_sheet.dart';
import 'package:solver/features/portfolio/widgets/add_holding_dialog.dart';
import 'package:solver/features/portfolio/widgets/add_watchlist_dialog.dart';
import 'package:solver/features/portfolio/widgets/holding_list.dart';
import 'package:solver/features/portfolio/widgets/portfolio_summary_card.dart';
import 'package:solver/features/portfolio/widgets/watchlist_section.dart';
import 'package:solver/shared/widgets/app_panel.dart';

class PortfolioView extends ConsumerStatefulWidget {
  const PortfolioView({super.key});

  @override
  ConsumerState<PortfolioView> createState() => _PortfolioViewState();
}

class _PortfolioViewState extends ConsumerState<PortfolioView> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      ref.invalidate(portfolioProvider);
      ref.invalidate(watchlistProvider);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
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

  Future<void> _openHoldingDetails(Holding holding) {
    return showAssetDetailSheet(
      context,
      symbol: holding.symbol,
      holding: holding,
    );
  }

  Future<void> _openWatchlistDetails(WatchlistItem item) {
    return showAssetDetailSheet(
      context,
      symbol: item.symbol,
      watchlistItem: item,
    );
  }

  Future<void> _deleteHolding(Holding holding) async {
    final confirmed = await _confirm(
      'Supprimer ${holding.symbol} ?',
      'Cette action est definitive.',
    );
    if (!mounted || !confirmed) return;

    try {
      await ref.read(portfolioMutationsProvider).deleteHolding(holding.id);
      _showSuccess('Position supprimee');
    } on DioException catch (e) {
      _showError(_extractApiError(e.response?.data));
    } catch (_) {
      _showError('Suppression impossible.');
    }
  }

  Future<void> _archiveHolding(Holding holding) async {
    try {
      await ref
          .read(portfolioMutationsProvider)
          .setHoldingArchived(holding.id, true);
      _showSuccess('Position archivee');
    } on DioException catch (e) {
      _showError(_extractApiError(e.response?.data));
    } catch (_) {
      _showError('Archivage impossible.');
    }
  }

  Future<void> _deleteWatchlistItem(WatchlistItem item) async {
    try {
      await ref.read(watchlistMutationsProvider).remove(item.id);
      _showSuccess('Supprime de la watchlist');
    } on DioException catch (e) {
      _showError(_extractApiError(e.response?.data));
    } catch (_) {
      _showError('Suppression impossible.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final portfolioAsync = ref.watch(portfolioProvider);
    final watchlistAsync = ref.watch(watchlistProvider);

    final portfolioData = portfolioAsync.valueOrNull;
    final holdings = portfolioData?.holdings ?? const <Holding>[];
    final watchlistItems =
        watchlistAsync.valueOrNull ?? const <WatchlistItem>[];

    final symbols = <String>{
      ...holdings.map((h) => h.symbol),
      ...watchlistItems.map((w) => w.symbol),
    }.toList()..sort();

    final sparklineAsync = ref.watch(
      sparklineBatchProvider(SparklineBatchRequest(symbols: symbols)),
    );

    final sparklineBySymbol = <String, List<double>>{};
    final sparklineMap = sparklineAsync.valueOrNull ?? const {};
    for (final entry in sparklineMap.entries) {
      sparklineBySymbol[entry.key] = entry.value.map((p) => p.close).toList();
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

    final isEmpty = holdings.isEmpty && watchlistItems.isEmpty;
    final anyStale =
        holdings.any((h) => h.isStale) || watchlistItems.any((w) => w.isStale);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;

        return Padding(
          padding: AppSpacing.paddingPage,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                onAddHolding: _openAddHoldingDialog,
                onRefresh: _refreshData,
              ),
              const SizedBox(height: AppSpacing.lg),
              PortfolioSummaryCard(summary: portfolioData.summary),
              Expanded(
                child: isEmpty
                    ? _EmptyState(onAddHolding: _openAddHoldingDialog)
                    : (isDesktop
                          ? _DesktopBody(
                              holdings: holdings,
                              watchlistItems: watchlistItems,
                              sparklineBySymbol: sparklineBySymbol,
                              onTapHolding: _openHoldingDetails,
                              onTapWatchlist: _openWatchlistDetails,
                              onDeleteHolding: _deleteHolding,
                              onArchiveHolding: _archiveHolding,
                              onDeleteWatchlistItem: _deleteWatchlistItem,
                              onAddWatchlist: _openAddWatchlistDialog,
                            )
                          : _MobileBody(
                              holdings: holdings,
                              watchlistItems: watchlistItems,
                              sparklineBySymbol: sparklineBySymbol,
                              onRefresh: _refreshData,
                              onTapHolding: _openHoldingDetails,
                              onTapWatchlist: _openWatchlistDetails,
                              onDeleteHolding: _deleteHolding,
                              onArchiveHolding: _archiveHolding,
                              onDeleteWatchlistItem: _deleteWatchlistItem,
                              onAddWatchlist: _openAddWatchlistDialog,
                            )),
              ),
              const SizedBox(height: AppSpacing.sm),
              _DelayedBadge(showWarning: anyStale),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _confirm(String title, String description) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    return result ?? false;
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _extractApiError(dynamic payload) {
    if (payload is String && payload.trim().isNotEmpty) return payload;
    if (payload is Map<String, dynamic>) {
      final error = payload['error'];
      if (error is String && error.trim().isNotEmpty) return error;
      final detail = payload['detail'];
      if (detail is String && detail.trim().isNotEmpty) return detail;
      final title = payload['title'];
      if (title is String && title.trim().isNotEmpty) return title;
    }
    return 'Une erreur est survenue.';
  }
}

class _Header extends StatelessWidget {
  final Future<void> Function() onAddHolding;
  final Future<void> Function() onRefresh;

  const _Header({required this.onAddHolding, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Portfolio',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          tooltip: 'Rafraichir',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
        ),
        const SizedBox(width: AppSpacing.sm),
        ElevatedButton.icon(
          onPressed: onAddHolding,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Ajouter'),
        ),
      ],
    );
  }
}

class _DesktopBody extends StatelessWidget {
  final List<Holding> holdings;
  final List<WatchlistItem> watchlistItems;
  final Map<String, List<double>> sparklineBySymbol;
  final Future<void> Function(Holding) onTapHolding;
  final Future<void> Function(WatchlistItem) onTapWatchlist;
  final void Function(Holding) onDeleteHolding;
  final void Function(Holding) onArchiveHolding;
  final void Function(WatchlistItem) onDeleteWatchlistItem;
  final Future<void> Function() onAddWatchlist;

  const _DesktopBody({
    required this.holdings,
    required this.watchlistItems,
    required this.sparklineBySymbol,
    required this.onTapHolding,
    required this.onTapWatchlist,
    required this.onDeleteHolding,
    required this.onArchiveHolding,
    required this.onDeleteWatchlistItem,
    required this.onAddWatchlist,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: AppPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mes positions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: HoldingList(
                    holdings: holdings,
                    sparklineBySymbol: sparklineBySymbol,
                    onTap: (holding) => onTapHolding(holding),
                    onDelete: onDeleteHolding,
                    onArchive: onArchiveHolding,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: SingleChildScrollView(
            child: WatchlistSection(
              items: watchlistItems,
              sparklineBySymbol: sparklineBySymbol,
              onTap: (item) => onTapWatchlist(item),
              onAdd: onAddWatchlist,
              onDelete: onDeleteWatchlistItem,
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileBody extends StatelessWidget {
  final List<Holding> holdings;
  final List<WatchlistItem> watchlistItems;
  final Map<String, List<double>> sparklineBySymbol;
  final Future<void> Function() onRefresh;
  final Future<void> Function(Holding) onTapHolding;
  final Future<void> Function(WatchlistItem) onTapWatchlist;
  final void Function(Holding) onDeleteHolding;
  final void Function(Holding) onArchiveHolding;
  final void Function(WatchlistItem) onDeleteWatchlistItem;
  final Future<void> Function() onAddWatchlist;

  const _MobileBody({
    required this.holdings,
    required this.watchlistItems,
    required this.sparklineBySymbol,
    required this.onRefresh,
    required this.onTapHolding,
    required this.onTapWatchlist,
    required this.onDeleteHolding,
    required this.onArchiveHolding,
    required this.onDeleteWatchlistItem,
    required this.onAddWatchlist,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Positions'),
              Tab(text: 'Watchlist'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: TabBarView(
              children: [
                RefreshIndicator(
                  onRefresh: onRefresh,
                  child: HoldingList(
                    holdings: holdings,
                    sparklineBySymbol: sparklineBySymbol,
                    onTap: (holding) => onTapHolding(holding),
                    onDelete: onDeleteHolding,
                    onArchive: onArchiveHolding,
                  ),
                ),
                RefreshIndicator(
                  onRefresh: onRefresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      WatchlistSection(
                        items: watchlistItems,
                        sparklineBySymbol: sparklineBySymbol,
                        onTap: (item) => onTapWatchlist(item),
                        onAdd: onAddWatchlist,
                        onDelete: onDeleteWatchlistItem,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

class _EmptyState extends StatelessWidget {
  final Future<void> Function() onAddHolding;

  const _EmptyState({required this.onAddHolding});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: AppPanel(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.insert_chart_outlined,
                  size: 36,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Votre portefeuille est vide',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Ajoutez vos premieres positions pour suivre vos investissements.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton.icon(
                  onPressed: onAddHolding,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Ajouter un actif'),
                ),
              ],
            ),
          ),
        ),
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
