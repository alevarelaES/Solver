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
import 'package:solver/features/portfolio/providers/trending_provider.dart';
import 'package:solver/features/portfolio/providers/watchlist_provider.dart';
import 'package:solver/features/portfolio/widgets/add_watchlist_dialog.dart';
import 'package:solver/features/portfolio/widgets/asset_row.dart';
import 'package:solver/shared/widgets/app_panel.dart';

enum _SidebarSection { invested, favorites }

class AssetSidebar extends ConsumerStatefulWidget {
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
  ConsumerState<AssetSidebar> createState() => _AssetSidebarState();
}

class _AssetSidebarState extends ConsumerState<AssetSidebar> {
  _SidebarSection _section = _SidebarSection.invested;
  String? _removingFavoriteId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final selected = ref.watch(selectedAssetProvider);
    final trendingAsync = ref.watch(trendingProvider);
    final watchlistAsync = ref.watch(watchlistProvider);
    final favorites = watchlistAsync.valueOrNull ?? const <WatchlistItem>[];
    final hasFavorites = favorites.isNotEmpty;
    final effectiveSection = hasFavorites ? _section : _SidebarSection.invested;

    return AppPanel(
      variant: AppPanelVariant.elevated,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryCard(summary: widget.summary),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _SidebarFilterChip(
                label: 'Investies',
                count: widget.holdings.length,
                selected: effectiveSection == _SidebarSection.invested,
                onTap: () {
                  setState(() => _section = _SidebarSection.invested);
                },
              ),
              _SidebarFilterChip(
                label: 'Favoris',
                count: favorites.length,
                selected: effectiveSection == _SidebarSection.favorites,
                onTap: () {
                  setState(() => _section = _SidebarSection.favorites);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text(
                effectiveSection == _SidebarSection.invested
                    ? 'MES POSITIONS INVESTIES'
                    : 'POSITIONS SUIVIES',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: textSecondary,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: effectiveSection == _SidebarSection.invested
                    ? widget.onAddHolding
                    : _openAddFavoriteDialog,
                icon: Icon(
                  effectiveSection == _SidebarSection.invested
                      ? Icons.add
                      : Icons.star_outline,
                  size: 16,
                ),
                visualDensity: VisualDensity.compact,
                tooltip: effectiveSection == _SidebarSection.invested
                    ? 'Ajouter une position'
                    : 'Ajouter un favori',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                if (effectiveSection == _SidebarSection.invested)
                  _buildInvestedList(selected, textSecondary)
                else
                  watchlistAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    error: (_, _) => Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      child: Text(
                        'Impossible de charger les favoris.',
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                    ),
                    data: (items) =>
                        _buildFavoritesList(items, selected, textSecondary),
                  ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'TOP MARCHÉ',
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
                      ...market.stocks.where((s) => (s.price ?? 0) > 0).take(3),
                      ...market.crypto.where((s) => (s.price ?? 0) > 0).take(2),
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
                            (stock) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.s6,
                              ),
                              child: AssetRow(
                                symbol: stock.symbol,
                                name: stock.name,
                                assetType: stock.assetType,
                                price: stock.price,
                                changePercent: stock.changePercent,
                                isSelected: selected?.symbol == stock.symbol,
                                onTap: () {
                                  ref
                                      .read(selectedAssetProvider.notifier)
                                      .state = SelectedAsset(
                                    symbol: stock.symbol,
                                  );
                                },
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
    );
  }

  Widget _buildInvestedList(SelectedAsset? selected, Color textSecondary) {
    if (widget.holdings.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(
          'Aucune position investie. Ajoutez un actif avec un montant investi.',
          style: TextStyle(fontSize: 12, color: textSecondary),
        ),
      );
    }

    final sorted = [...widget.holdings]
      ..sort((a, b) => (b.totalValue ?? 0).compareTo(a.totalValue ?? 0));

    return Column(
      children: sorted
          .map(
            (holding) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s6),
              child: AssetRow(
                symbol: holding.symbol,
                name: holding.name,
                assetType: holding.assetType,
                price: holding.currentPrice,
                changePercent: holding.changePercent,
                sparklineData: widget.sparklineBySymbol[holding.symbol],
                isSelected: selected?.symbol == holding.symbol,
                onTap: () {
                  ref.read(selectedAssetProvider.notifier).state =
                      SelectedAsset(symbol: holding.symbol, holding: holding);
                },
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildFavoritesList(
    List<WatchlistItem> items,
    SelectedAsset? selected,
    Color textSecondary,
  ) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(
          'Aucun favori. Ajoutez vos symboles suivis.',
          style: TextStyle(fontSize: 12, color: textSecondary),
        ),
      );
    }

    final sorted = [...items]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return Column(
      children: sorted
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s6),
              child: AssetRow(
                symbol: item.symbol,
                name: item.name,
                assetType: item.assetType,
                price: item.currentPrice,
                changePercent: item.changePercent,
                sparklineData: widget.sparklineBySymbol[item.symbol],
                isSelected: selected?.symbol == item.symbol,
                onTap: () {
                  Holding? matchingHolding;
                  for (final holding in widget.holdings) {
                    if (holding.symbol.toUpperCase() ==
                        item.symbol.toUpperCase()) {
                      matchingHolding = holding;
                      break;
                    }
                  }
                  ref
                      .read(selectedAssetProvider.notifier)
                      .state = SelectedAsset(
                    symbol: item.symbol,
                    holding: matchingHolding,
                    watchlistItem: item,
                  );
                },
                trailingWidget: IconButton(
                  tooltip: 'Retirer des favoris',
                  onPressed: _removingFavoriteId == item.id
                      ? null
                      : () => _removeFavorite(item),
                  visualDensity: VisualDensity.compact,
                  icon: _removingFavoriteId == item.id
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.star, size: 16, color: AppColors.warning),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> _openAddFavoriteDialog() async {
    final added = await showAddWatchlistDialog(context);
    if (!mounted || !added) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Favori ajoute'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _removeFavorite(WatchlistItem item) async {
    setState(() => _removingFavoriteId = item.id);
    try {
      await ref.read(watchlistMutationsProvider).remove(item.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Suppression impossible pour le moment.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _removingFavoriteId = null);
      }
    }
  }
}

class _SidebarFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarFilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.xs),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.12) : null,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.borderLight,
          ),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.primary : textSecondary,
          ),
        ),
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
          ? AppColors.portfolioSurfaceDark
          : AppColors.portfolioSurfaceLight,
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
                'G/P ${AppFormats.currency.format(summary.totalGainLoss)}',
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
