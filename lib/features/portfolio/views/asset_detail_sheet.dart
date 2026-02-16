import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/portfolio/models/holding.dart';
import 'package:solver/features/portfolio/models/watchlist_item.dart';
import 'package:solver/features/portfolio/providers/company_news_provider.dart';
import 'package:solver/features/portfolio/providers/company_profile_provider.dart';
import 'package:solver/features/portfolio/providers/price_stream_provider.dart';
import 'package:solver/features/portfolio/widgets/analyst_gauge.dart';
import 'package:solver/features/portfolio/widgets/company_profile_header.dart';
import 'package:solver/features/portfolio/widgets/news_list.dart';
import 'package:solver/features/portfolio/widgets/price_chart.dart';
import 'package:solver/shared/widgets/app_panel.dart';

Future<void> showAssetDetailSheet(
  BuildContext context, {
  required String symbol,
  Holding? holding,
  WatchlistItem? watchlistItem,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.92,
      child: AssetDetailSheet(
        symbol: symbol,
        holding: holding,
        watchlistItem: watchlistItem,
      ),
    ),
  );
}

class AssetDetailSheet extends ConsumerStatefulWidget {
  final String symbol;
  final Holding? holding;
  final WatchlistItem? watchlistItem;

  const AssetDetailSheet({
    super.key,
    required this.symbol,
    this.holding,
    this.watchlistItem,
  });

  @override
  ConsumerState<AssetDetailSheet> createState() => _AssetDetailSheetState();
}

class _AssetDetailSheetState extends ConsumerState<AssetDetailSheet> {
  PriceChartPeriod _period = PriceChartPeriod.oneMonth;
  double? _lastSeenPrice;
  Color? _flashColor;

  @override
  Widget build(BuildContext context) {
    final symbol = widget.symbol.toUpperCase();

    ref.listen<AsyncValue<PriceUpdate>>(priceStreamProvider(symbol), (
      prev,
      next,
    ) {
      final incoming = next.valueOrNull?.price;
      if (incoming == null) return;

      if (_lastSeenPrice == null || _lastSeenPrice == incoming) {
        setState(() {
          _lastSeenPrice = incoming;
          _flashColor = null;
        });
        return;
      }

      setState(() {
        _flashColor = incoming > _lastSeenPrice!
            ? AppColors.success
            : AppColors.danger;
        _lastSeenPrice = incoming;
      });
    });

    final profileAsync = ref.watch(companyProfileProvider(symbol));
    final newsAsync = ref.watch(companyNewsProvider(symbol));
    final recoAsync = ref.watch(analystRecommendationsProvider(symbol));
    final streamAsync = ref.watch(priceStreamProvider(symbol));

    final streamPrice = streamAsync.valueOrNull?.price;
    final fallbackPrice =
        widget.holding?.currentPrice ?? widget.watchlistItem?.currentPrice;
    final currentPrice = streamPrice ?? fallbackPrice;

    final changePercent =
        widget.holding?.changePercent ?? widget.watchlistItem?.changePercent;

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          _SheetHeader(symbol: symbol),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  profileAsync.when(
                    loading: () => const _LoadingPanel(height: 72),
                    error: (error, _) =>
                        AppPanel(child: Text('Profil indisponible: $error')),
                    data: (profile) => profile == null
                        ? AppPanel(child: Text('Aucun profil pour $symbol.'))
                        : CompanyProfileHeader(profile: profile),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            currentPrice == null
                                ? '--'
                                : AppFormats.currency.format(currentPrice),
                            key: ValueKey(
                              currentPrice?.toStringAsFixed(6) ?? '--',
                            ),
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color:
                                  _flashColor ??
                                  (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          changePercent == null
                              ? 'Variation journaliere: --'
                              : 'Variation journaliere: ${_formatPercent(changePercent)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: changePercent == null
                                ? (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight)
                                : (changePercent >= 0
                                      ? AppColors.success
                                      : AppColors.danger),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _PeriodSelector(
                    selected: _period,
                    onChanged: (period) => setState(() => _period = period),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PriceChart(symbol: symbol, period: _period),
                  const SizedBox(height: AppSpacing.md),
                  if (widget.holding != null)
                    _PositionPanel(holding: widget.holding!),
                  if (widget.holding != null)
                    const SizedBox(height: AppSpacing.md),
                  recoAsync.when(
                    loading: () => const _LoadingPanel(height: 80),
                    error: (error, _) => AppPanel(
                      child: Text('Recommandations indisponibles: $error'),
                    ),
                    data: (recommendations) {
                      if (recommendations.isEmpty) {
                        return const AppPanel(
                          child: Text('Aucune recommandation analyste.'),
                        );
                      }
                      return AnalystGauge(
                        recommendation: recommendations.first,
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  newsAsync.when(
                    loading: () => const _LoadingPanel(height: 150),
                    error: (error, _) => AppPanel(
                      child: Text('Actualites indisponibles: $error'),
                    ),
                    data: (news) => NewsList(news: news),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPercent(double value) {
    final sign = value >= 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(2)}%';
  }
}

class _SheetHeader extends StatelessWidget {
  final String symbol;

  const _SheetHeader({required this.symbol});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Fermer',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
          ),
          Text(
            symbol,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final PriceChartPeriod selected;
  final ValueChanged<PriceChartPeriod> onChanged;

  const _PeriodSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      children: PriceChartPeriod.values
          .map(
            (period) => ChoiceChip(
              label: Text(period.label),
              selected: selected == period,
              onSelected: (_) => onChanged(period),
            ),
          )
          .toList(),
    );
  }
}

class _PositionPanel extends StatelessWidget {
  final Holding holding;

  const _PositionPanel({required this.holding});

  @override
  Widget build(BuildContext context) {
    final invested = (holding.averageBuyPrice ?? 0) * holding.quantity;

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ma position',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('${holding.quantity.toStringAsFixed(2)} actions'),
          Text('Investi: ${AppFormats.currency.format(invested)}'),
          Text(
            'Valeur: ${holding.totalValue == null ? '--' : AppFormats.currency.format(holding.totalValue)}',
          ),
          Text(
            'Gain: ${holding.totalGainLoss == null ? '--' : AppFormats.currency.format(holding.totalGainLoss)}',
          ),
        ],
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  final double height;

  const _LoadingPanel({required this.height});

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
