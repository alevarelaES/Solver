import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/portfolio/data/portfolio_trending_catalog.dart';
import 'package:solver/features/portfolio/models/symbol_search_result.dart';
import 'package:solver/features/portfolio/models/trending_stock.dart';
import 'package:solver/features/portfolio/providers/selected_asset_provider.dart';
import 'package:solver/features/portfolio/providers/trending_provider.dart';
import 'package:solver/features/portfolio/widgets/asset_detail_inline.dart';
import 'package:solver/features/portfolio/widgets/news_list.dart';
import 'package:solver/features/portfolio/widgets/symbol_search_field.dart';
import 'package:solver/features/portfolio/widgets/trending_card.dart';
import 'package:solver/shared/widgets/app_panel.dart';

class MarketTab extends ConsumerWidget {
  const MarketTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedAssetProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > AppBreakpoints.desktop;

        if (isDesktop) {
          return _DesktopLayout(selected: selected);
        }

        return _MobileLayout(selected: selected);
      },
    );
  }
}

class _DesktopLayout extends ConsumerWidget {
  final SelectedAsset? selected;

  const _DesktopLayout({required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: Search panel
        SizedBox(width: 300, child: _SearchPanel()),
        const SizedBox(width: AppSpacing.lg),
        // Right: Detail or trending + news
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
              : const _MarketContent(),
        ),
      ],
    );
  }
}

class _MobileLayout extends ConsumerWidget {
  final SelectedAsset? selected;

  const _MobileLayout({required this.selected});

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

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SearchPanel(),
          const SizedBox(height: AppSpacing.lg),
          const _MarketContent(),
        ],
      ),
    );
  }
}

class _SearchPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppPanel(
      variant: AppPanelVariant.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'DECOVERTE MARCHE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SymbolSearchField(
            label: 'Rechercher un symbole',
            onSelected: (SymbolSearchResult result) {
              ref.read(selectedAssetProvider.notifier).state = SelectedAsset(
                symbol: result.symbol,
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: marketQuickSearchSymbols
                .map(
                  (symbol) => ActionChip(
                    label: Text(symbol),
                    onPressed: () {
                      ref.read(selectedAssetProvider.notifier).state =
                          SelectedAsset(symbol: symbol);
                    },
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _MarketContent extends ConsumerWidget {
  const _MarketContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    final trendingAsync = ref.watch(trendingProvider);
    final newsAsync = ref.watch(marketNewsProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          trendingAsync.when(
            loading: () => const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, _) => AppPanel(
              child: Text(
                'Impossible de charger les tendances.',
                style: TextStyle(color: textSecondary),
              ),
            ),
            data: (market) {
              final stocks = market.stocks;
              final crypto = market.crypto;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MarketHero(stocks: stocks, crypto: crypto),
                  const SizedBox(height: AppSpacing.lg),
                  _SectionHeader(
                    title: 'ACTIONS POPULAIRES',
                    subtitle: '${stocks.length} actifs',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _TrendingGrid(stocks: stocks),
                  const SizedBox(height: AppSpacing.lg),
                  _SectionHeader(
                    title: 'CRYPTO EN TENDANCE',
                    subtitle: '${crypto.length} actifs',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (crypto.isEmpty)
                    AppPanel(
                      child: Text(
                        'Flux crypto indisponible pour le moment.',
                        style: TextStyle(color: textSecondary),
                      ),
                    )
                  else
                    _TrendingGrid(stocks: crypto),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          _SectionHeader(title: 'ACTUALITES DU MARCHE'),
          const SizedBox(height: AppSpacing.sm),
          newsAsync.when(
            loading: () => const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, _) => AppPanel(
              child: Text(
                'Actualites indisponibles.',
                style: TextStyle(color: textSecondary),
              ),
            ),
            data: (news) => NewsList(news: news.take(8).toList()),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: textSecondary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 11,
              color: textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _MarketHero extends StatelessWidget {
  final List<TrendingStock> stocks;
  final List<TrendingStock> crypto;

  const _MarketHero({required this.stocks, required this.crypto});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    final movers = [...stocks, ...crypto];
    final green = movers.where((s) => (s.changePercent ?? 0) >= 0).length;
    final red = movers.length - green;

    return AppPanel(
      variant: AppPanelVariant.elevated,
      backgroundColor: isDark
          ? AppColors.portfolioSurfaceDark
          : AppColors.portfolioSurfaceLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'VUE MARCHE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Suivi live des leaders actions et crypto.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _KpiPill(label: 'Actions', value: '${stocks.length}'),
              _KpiPill(label: 'Crypto', value: '${crypto.length}'),
              _KpiPill(label: 'En hausse', value: '$green'),
              _KpiPill(
                label: 'En baisse',
                value: '$red',
                color: AppColors.danger,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Données retardées 15 min selon la bourse.',
            style: TextStyle(fontSize: 11, color: textSecondary),
          ),
        ],
      ),
    );
  }
}

class _KpiPill extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _KpiPill({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: resolved.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.r16),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 11,
          color: resolved,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TrendingGrid extends ConsumerWidget {
  final List<TrendingStock> stocks;

  const _TrendingGrid({required this.stocks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (stocks.isEmpty) {
      return AppPanel(
        child: Text(
          'Aucune donnee disponible.',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossCount = width > 1100
            ? 4
            : width > 760
            ? 3
            : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.6,
          ),
          itemCount: stocks.length,
          itemBuilder: (context, index) {
            final stock = stocks[index];
            return TrendingCard(
              stock: stock,
              onTap: () {
                ref.read(selectedAssetProvider.notifier).state = SelectedAsset(
                  symbol: stock.symbol,
                );
              },
            );
          },
        );
      },
    );
  }
}
