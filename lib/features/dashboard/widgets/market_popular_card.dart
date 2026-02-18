import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/portfolio/models/trending_stock.dart';
import 'package:solver/features/portfolio/providers/trending_provider.dart';
import 'package:solver/features/portfolio/widgets/asset_logo.dart';
import 'package:solver/shared/widgets/glass_container.dart';

enum _PopularSortMode { movers, gainers, losers }

class MarketPopularCard extends ConsumerStatefulWidget {
  const MarketPopularCard({super.key});

  @override
  ConsumerState<MarketPopularCard> createState() => _MarketPopularCardState();
}

class _MarketPopularCardState extends ConsumerState<MarketPopularCard> {
  _PopularSortMode _sortMode = _PopularSortMode.movers;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trendingAsync = ref.watch(trendingProvider);

    return GlassContainer(
      padding: AppSpacing.paddingCardCompact,
      child: trendingAsync.when(
        loading: () => const SizedBox(
          height: 180,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, _) => SizedBox(
          height: 120,
          child: Center(
            child: Text(
              'Actions populaires indisponibles',
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
        ),
        data: (market) {
          final display = _sortedStocks(market.stocks).take(6).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Actions populaires',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  _SortChip(
                    label: 'Mouvements',
                    selected: _sortMode == _PopularSortMode.movers,
                    onTap: () =>
                        setState(() => _sortMode = _PopularSortMode.movers),
                  ),
                  _SortChip(
                    label: 'Gagnants',
                    selected: _sortMode == _PopularSortMode.gainers,
                    onTap: () =>
                        setState(() => _sortMode = _PopularSortMode.gainers),
                  ),
                  _SortChip(
                    label: 'Perdants',
                    selected: _sortMode == _PopularSortMode.losers,
                    onTap: () =>
                        setState(() => _sortMode = _PopularSortMode.losers),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (display.isEmpty)
                Text(
                  'Aucune action disponible',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                )
              else
                ...display.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: GestureDetector(
                      onTap: () => context.go('/portfolio'),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: _MarketRow(item: item),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<TrendingStock> _sortedStocks(List<TrendingStock> input) {
    final stocks = [...input];
    switch (_sortMode) {
      case _PopularSortMode.movers:
        stocks.sort(
          (a, b) => (b.changePercent ?? 0).abs().compareTo(
            (a.changePercent ?? 0).abs(),
          ),
        );
        return stocks;
      case _PopularSortMode.gainers:
        stocks.sort(
          (a, b) =>
              (b.changePercent ?? -999).compareTo(a.changePercent ?? -999),
        );
        return stocks.where((s) => (s.changePercent ?? 0) >= 0).toList();
      case _PopularSortMode.losers:
        stocks.sort(
          (a, b) => (a.changePercent ?? 999).compareTo(b.changePercent ?? 999),
        );
        return stocks.where((s) => (s.changePercent ?? 0) < 0).toList();
    }
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.xs),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.12) : null,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.borderLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _MarketRow extends StatelessWidget {
  final TrendingStock item;

  const _MarketRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final value = item.changePercent ?? 0;
    final up = value >= 0;
    final accent = up ? AppColors.success : AppColors.danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
        color: accent.withValues(alpha: isDark ? 0.12 : 0.07),
      ),
      child: Row(
        children: [
          AssetLogo(symbol: item.symbol, assetType: item.assetType, size: 24),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.symbol,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                if ((item.name ?? '').isNotEmpty)
                  Text(
                    item.name!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            item.price == null ? '--' : item.price!.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(width: 8),
          _DeltaBadge(percent: item.changePercent),
        ],
      ),
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  final double? percent;

  const _DeltaBadge({required this.percent});

  @override
  Widget build(BuildContext context) {
    final value = percent ?? 0;
    final up = value >= 0;
    final color = up ? AppColors.success : AppColors.danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        percent == null ? '--' : '${up ? '+' : ''}${value.toStringAsFixed(2)}%',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
