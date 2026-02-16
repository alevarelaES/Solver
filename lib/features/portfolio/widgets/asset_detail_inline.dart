import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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

class AssetDetailInline extends ConsumerStatefulWidget {
  final String symbol;
  final Holding? holding;
  final WatchlistItem? watchlistItem;
  final VoidCallback? onClose;

  const AssetDetailInline({
    super.key,
    required this.symbol,
    this.holding,
    this.watchlistItem,
    this.onClose,
  });

  @override
  ConsumerState<AssetDetailInline> createState() => _AssetDetailInlineState();
}

class _AssetDetailInlineState extends ConsumerState<AssetDetailInline> {
  PriceChartPeriod _period = PriceChartPeriod.oneMonth;
  double? _lastSeenPrice;
  Color? _flashColor;

  @override
  Widget build(BuildContext context) {
    final symbol = widget.symbol.toUpperCase();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

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
        _flashColor =
            incoming > _lastSeenPrice! ? AppColors.success : AppColors.danger;
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with symbol + close button
        Row(
          children: [
            if (widget.onClose != null)
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                onPressed: widget.onClose,
                tooltip: 'Retour',
              ),
            Text(
              symbol,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const Spacer(),
            if (widget.onClose != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: widget.onClose,
                tooltip: 'Fermer',
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Company profile
                profileAsync.when(
                  loading: () => _LoadingBox(height: 72),
                  error: (error, _) =>
                      AppPanel(child: Text('Profil indisponible')),
                  data: (profile) => profile == null
                      ? AppPanel(child: Text('Aucun profil pour $symbol.'))
                      : CompanyProfileHeader(profile: profile),
                ),
                const SizedBox(height: AppSpacing.md),

                // Price panel
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
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: _flashColor ??
                                textPrimary,
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
                              ? textSecondary
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

                // Period selector
                _PeriodSelector(
                  selected: _period,
                  onChanged: (period) => setState(() => _period = period),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Chart (bigger for inline)
                SizedBox(
                  height: 300,
                  child: PriceChart(symbol: symbol, period: _period),
                ),
                const SizedBox(height: AppSpacing.md),

                // Position panel (if holding)
                if (widget.holding != null)
                  _PositionPanel(holding: widget.holding!),
                if (widget.holding != null)
                  const SizedBox(height: AppSpacing.md),

                // Analyst gauge
                recoAsync.when(
                  loading: () => _LoadingBox(height: 80),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (recommendations) {
                    if (recommendations.isEmpty) return const SizedBox.shrink();
                    return AnalystGauge(
                      recommendation: recommendations.first,
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // News
                newsAsync.when(
                  loading: () => _LoadingBox(height: 150),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (news) => NewsList(news: news),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatPercent(double value) {
    final sign = value >= 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(2)}%';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final invested = (holding.averageBuyPrice ?? 0) * holding.quantity;

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MA POSITION',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _PositionMetric(
                label: 'Quantite',
                value: holding.quantity.toStringAsFixed(2),
              ),
              const SizedBox(width: AppSpacing.xl),
              _PositionMetric(
                label: 'Investi',
                value: AppFormats.currency.format(invested),
              ),
              const SizedBox(width: AppSpacing.xl),
              _PositionMetric(
                label: 'Valeur',
                value: holding.totalValue == null
                    ? '--'
                    : AppFormats.currency.format(holding.totalValue),
              ),
              const SizedBox(width: AppSpacing.xl),
              _PositionMetric(
                label: 'Gain/Perte',
                value: holding.totalGainLoss == null
                    ? '--'
                    : AppFormats.currency.format(holding.totalGainLoss),
                color: holding.totalGainLoss != null
                    ? (holding.totalGainLoss! >= 0
                        ? AppColors.success
                        : AppColors.danger)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PositionMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _PositionMetric({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: textSecondary),
        ),
        Text(
          value,
          style: GoogleFonts.robotoMono(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color ?? textPrimary,
          ),
        ),
      ],
    );
  }
}

class _LoadingBox extends StatelessWidget {
  final double height;

  const _LoadingBox({required this.height});

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
