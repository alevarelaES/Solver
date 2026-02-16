import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/portfolio/models/symbol_search_result.dart';
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
        SizedBox(
          width: 300,
          child: _SearchPanel(),
        ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SymbolSearchField(
            label: 'Rechercher un symbole',
            onSelected: (SymbolSearchResult result) {
              ref.read(selectedAssetProvider.notifier).state = SelectedAsset(
                symbol: result.symbol,
              );
            },
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
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final trendingAsync = ref.watch(trendingProvider);
    final newsAsync = ref.watch(marketNewsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Trending section
        Text(
          'ACTIONS POPULAIRES',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        trendingAsync.when(
          loading: () => const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, _) => AppPanel(
            child: Text(
              'Impossible de charger les tendances.',
              style: TextStyle(color: textSecondary),
            ),
          ),
          data: (stocks) {
            if (stocks.isEmpty) {
              return AppPanel(
                child: Text(
                  'Aucune donnee disponible.',
                  style: TextStyle(color: textSecondary),
                ),
              );
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final crossCount = constraints.maxWidth > 600 ? 3 : 2;
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
                        ref.read(selectedAssetProvider.notifier).state =
                            SelectedAsset(symbol: stock.symbol);
                      },
                    );
                  },
                );
              },
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),

        // Market news
        Text(
          'ACTUALITES DU MARCHE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: textSecondary,
          ),
        ),
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
          data: (news) => NewsList(news: news),
        ),
      ],
    );
  }
}
