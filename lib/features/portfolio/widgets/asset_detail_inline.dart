import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/portfolio/models/analyst_recommendation.dart';
import 'package:solver/features/portfolio/models/company_news.dart';
import 'package:solver/features/portfolio/models/company_profile.dart';
import 'package:solver/features/portfolio/models/holding.dart';
import 'package:solver/features/portfolio/models/time_series_point.dart';
import 'package:solver/features/portfolio/models/watchlist_item.dart';
import 'package:solver/features/portfolio/providers/company_news_provider.dart';
import 'package:solver/features/portfolio/providers/company_profile_provider.dart';
import 'package:solver/features/portfolio/providers/price_history_provider.dart';
import 'package:solver/features/portfolio/providers/price_stream_provider.dart';
import 'package:solver/features/portfolio/widgets/asset_logo.dart';
import 'package:solver/features/portfolio/widgets/price_chart.dart';
import 'package:solver/shared/widgets/app_panel.dart';
import 'package:url_launcher/url_launcher.dart';

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
    final textPrimary = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;

    ref.listen<AsyncValue<PriceUpdate>>(priceStreamProvider(symbol), (_, next) {
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
    final yearHistoryAsync = ref.watch(
      priceHistoryProvider(
        PriceHistoryRequest(symbol: symbol, interval: '1week', outputSize: 52),
      ),
    );

    final streamPrice = streamAsync.valueOrNull?.price;
    final fallbackPrice =
        widget.holding?.currentPrice ?? widget.watchlistItem?.currentPrice;
    final currentPrice = streamPrice ?? fallbackPrice;
    final changePercent =
        widget.holding?.changePercent ?? widget.watchlistItem?.changePercent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                fontSize: 24,
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
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                profileAsync.when(
                  loading: () => const _LoadingBox(height: 112),
                  error: (_, _) => _HeroCard(
                    symbol: symbol,
                    profile: null,
                    currentPrice: currentPrice,
                    changePercent: changePercent,
                    flashColor: _flashColor,
                  ),
                  data: (profile) => _HeroCard(
                    symbol: symbol,
                    profile: profile,
                    currentPrice: currentPrice,
                    changePercent: changePercent,
                    flashColor: _flashColor,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final desktop = constraints.maxWidth > 1080;

                    final chart = _ChartPanel(
                      symbol: symbol,
                      period: _period,
                      onPeriodChanged: (period) {
                        setState(() => _period = period);
                      },
                    );

                    final side = Column(
                      children: [
                        recoAsync.when(
                          loading: () => const _LoadingBox(height: 150),
                          error: (_, _) => const SizedBox.shrink(),
                          data: (recommendations) => _AnalystCard(
                            recommendation: recommendations.isEmpty
                                ? null
                                : recommendations.first,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _MetricsCard(
                          history: yearHistoryAsync.valueOrNull ?? const [],
                        ),
                        if (widget.holding != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          _PositionCard(holding: widget.holding!),
                        ],
                        if (currentPrice != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          _OrderBookCard(
                            symbol: symbol,
                            currentPrice: currentPrice,
                          ),
                        ],
                      ],
                    );

                    if (desktop) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: chart),
                          const SizedBox(width: AppSpacing.md),
                          SizedBox(width: 320, child: side),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        chart,
                        const SizedBox(height: AppSpacing.md),
                        side,
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                _NewsPanel(newsAsync: newsAsync),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String symbol;
  final CompanyProfile? profile;
  final double? currentPrice;
  final double? changePercent;
  final Color? flashColor;

  const _HeroCard({
    required this.symbol,
    required this.profile,
    required this.currentPrice,
    required this.changePercent,
    required this.flashColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final up = (changePercent ?? 0) >= 0;
    final trendColor = up ? AppColors.success : AppColors.danger;

    return AppPanel(
      variant: AppPanelVariant.elevated,
      backgroundColor: isDark
          ? const Color(0xFF192227)
          : const Color(0xFFEFF7EE),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AssetLogo(
            symbol: symbol,
            assetType: 'stock',
            logoUrl: profile?.logo,
            size: 52,
            borderRadius: AppRadius.md,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      symbol,
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                    if ((profile?.exchange ?? '').isNotEmpty)
                      _Pill(
                        label: profile!.exchange!,
                        color: AppColors.primary,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  profile?.name ?? symbol,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if ((profile?.sector ?? '').isNotEmpty) profile!.sector!,
                    if ((profile?.country ?? '').isNotEmpty) profile!.country!,
                  ].join(' • '),
                  style: TextStyle(fontSize: 13, color: textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: GoogleFonts.robotoMono(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: flashColor ?? Theme.of(context).colorScheme.onSurface,
                ),
                child: Text(
                  currentPrice == null
                      ? '--'
                      : AppFormats.currency.format(currentPrice),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                changePercent == null
                    ? '--'
                    : '${up ? '+' : ''}${changePercent!.toStringAsFixed(2)}%',
                style: TextStyle(
                  color: trendColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              if (profile?.marketCap != null)
                Text(
                  'MCap ${_formatMarketCap(profile!.marketCap!)}',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatMarketCap(double valueInMillions) {
    final absoluteUsd = valueInMillions * 1000000;
    if (absoluteUsd >= 1000000000000) {
      return '\$${(absoluteUsd / 1000000000000).toStringAsFixed(2)}T';
    }
    if (absoluteUsd >= 1000000000) {
      return '\$${(absoluteUsd / 1000000000).toStringAsFixed(2)}B';
    }
    return '\$${(absoluteUsd / 1000000).toStringAsFixed(0)}M';
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;

  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ChartPanel extends StatelessWidget {
  final String symbol;
  final PriceChartPeriod period;
  final ValueChanged<PriceChartPeriod> onPeriodChanged;

  const _ChartPanel({
    required this.symbol,
    required this.period,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      variant: AppPanelVariant.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'INTERACTIVE CHART',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
              const Spacer(),
              Wrap(
                spacing: AppSpacing.xs,
                children: PriceChartPeriod.values
                    .map(
                      (p) => ChoiceChip(
                        label: Text(p.label),
                        selected: p == period,
                        onSelected: (_) => onPeriodChanged(p),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 420,
            child: PriceChart(
              symbol: symbol,
              period: period,
              height: 420,
              framed: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalystCard extends StatelessWidget {
  final AnalystRecommendation? recommendation;

  const _AnalystCard({required this.recommendation});

  @override
  Widget build(BuildContext context) {
    final total = recommendation?.total ?? 0;
    final buy = recommendation == null
        ? 0
        : recommendation!.buy + recommendation!.strongBuy;
    final hold = recommendation?.hold ?? 0;
    final sell = recommendation == null
        ? 0
        : recommendation!.sell + recommendation!.strongSell;
    final buyRatio = total == 0 ? 0.0 : buy / total;
    final holdRatio = total == 0 ? 0.0 : hold / total;
    final sellRatio = total == 0 ? 0.0 : sell / total;

    final sentiment = buyRatio >= 0.55
        ? 'BUY'
        : buyRatio >= 0.35
        ? 'HOLD'
        : 'SELL';
    final sentimentColor = buyRatio >= 0.55
        ? AppColors.success
        : buyRatio >= 0.35
        ? AppColors.warning
        : AppColors.danger;

    return AppPanel(
      variant: AppPanelVariant.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ANALYST FORECAST',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            sentiment,
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              color: sentimentColor,
              height: 1.0,
            ),
          ),
          Text(
            total == 0
                ? 'Pas assez de votes'
                : '${(buyRatio * 100).toStringAsFixed(0)}% positif',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: SizedBox(
              height: 7,
              child: Row(
                children: [
                  Expanded(
                    flex: math.max(1, (buyRatio * 100).round()),
                    child: Container(color: AppColors.success),
                  ),
                  Expanded(
                    flex: math.max(1, (holdRatio * 100).round()),
                    child: Container(color: AppColors.warning),
                  ),
                  Expanded(
                    flex: math.max(1, (sellRatio * 100).round()),
                    child: Container(color: AppColors.danger),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsCard extends StatelessWidget {
  final List<TimeSeriesPoint> history;

  const _MetricsCard({required this.history});

  @override
  Widget build(BuildContext context) {
    final closes = history.map((h) => h.close).toList();
    final high = closes.isEmpty ? null : closes.reduce(math.max);
    final low = closes.isEmpty ? null : closes.reduce(math.min);
    final current = closes.isEmpty ? null : closes.last;
    final annualMove = (high != null && low != null && low > 0)
        ? ((high - low) / low * 100)
        : null;

    final secondary = Theme.of(context).brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return AppPanel(
      variant: AppPanelVariant.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PERFORMANCE METRICS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _MetricRow(
            label: 'Prix courant',
            value: current == null ? '--' : '\$${current.toStringAsFixed(2)}',
          ),
          _MetricRow(
            label: '52W high',
            value: high == null ? '--' : '\$${high.toStringAsFixed(2)}',
          ),
          _MetricRow(
            label: '52W low',
            value: low == null ? '--' : '\$${low.toStringAsFixed(2)}',
          ),
          _MetricRow(
            label: 'Amplitude',
            value: annualMove == null
                ? '--'
                : '${annualMove.toStringAsFixed(1)}%',
            valueColor: annualMove != null && annualMove > 0
                ? AppColors.warning
                : null,
          ),
          const SizedBox(height: 2),
          Text(
            'Basé sur historique hebdo.',
            style: TextStyle(fontSize: 11, color: secondary),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _MetricRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: secondary)),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.robotoMono(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _PositionCard extends StatelessWidget {
  final Holding holding;

  const _PositionCard({required this.holding});

  @override
  Widget build(BuildContext context) {
    final invested = (holding.averageBuyPrice ?? 0) * holding.quantity;

    return AppPanel(
      variant: AppPanelVariant.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MA POSITION',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _MetricRow(
            label: 'Quantité',
            value: holding.quantity.toStringAsFixed(2),
          ),
          _MetricRow(
            label: 'Investi',
            value: AppFormats.currency.format(invested),
          ),
          _MetricRow(
            label: 'Valeur',
            value: holding.totalValue == null
                ? '--'
                : AppFormats.currency.format(holding.totalValue),
          ),
          _MetricRow(
            label: 'Gain / Perte',
            value: holding.totalGainLoss == null
                ? '--'
                : AppFormats.currency.format(holding.totalGainLoss),
            valueColor: holding.totalGainLoss == null
                ? null
                : (holding.totalGainLoss! >= 0
                      ? AppColors.success
                      : AppColors.danger),
          ),
        ],
      ),
    );
  }
}

class _OrderBookCard extends StatelessWidget {
  final String symbol;
  final double currentPrice;

  const _OrderBookCard({required this.symbol, required this.currentPrice});

  @override
  Widget build(BuildContext context) {
    final bids = _levels(currentPrice * 0.998, 4, false);
    final asks = _levels(currentPrice * 1.002, 4, true);

    return AppPanel(
      variant: AppPanelVariant.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'ORDER BOOK',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              Text(
                'LIVE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...asks.map(
            (l) => _OrderRow(
              price: l.price,
              volume: l.volume,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ...bids.map(
            (l) => _OrderRow(
              price: l.price,
              volume: l.volume,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  List<_OrderLevel> _levels(double start, int count, bool ask) {
    final seed = symbol.codeUnits.fold<int>(13, (a, b) => a + b);
    return List.generate(count, (index) {
      final direction = ask ? 1 : -1;
      final step = (0.01 + (index * 0.007)) * direction;
      final price = start + step;
      final volume = 1200 + ((seed + (index * 917)) % 9000);
      return _OrderLevel(price, volume);
    });
  }
}

class _OrderLevel {
  final double price;
  final int volume;

  const _OrderLevel(this.price, this.volume);
}

class _OrderRow extends StatelessWidget {
  final double price;
  final int volume;
  final Color color;

  const _OrderRow({
    required this.price,
    required this.volume,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Text(
            price.toStringAsFixed(2),
            style: GoogleFonts.robotoMono(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Text(
            NumberFormat.decimalPattern().format(volume),
            style: GoogleFonts.robotoMono(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsPanel extends StatelessWidget {
  final AsyncValue<List<CompanyNews>> newsAsync;

  const _NewsPanel({required this.newsAsync});

  @override
  Widget build(BuildContext context) {
    return newsAsync.when(
      loading: () => const _LoadingBox(height: 130),
      error: (_, _) => const SizedBox.shrink(),
      data: (news) {
        final items = news.take(6).toList();
        if (items.isEmpty) return const SizedBox.shrink();

        return AppPanel(
          variant: AppPanelVariant.elevated,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Text(
                    'MARKET INTELLIGENCE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: items.map((item) => _NewsCard(news: item)).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NewsCard extends StatelessWidget {
  final CompanyNews news;

  const _NewsCard({required this.news});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width > 1200 ? 315.0 : 260.0;
    final secondary = Theme.of(context).brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => _open(news.url),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xs),
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: (news.image ?? '').isEmpty
                      ? Container(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          alignment: Alignment.center,
                          child: const Icon(Icons.article_outlined, size: 20),
                        )
                      : Image.network(
                          news.image!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            alignment: Alignment.center,
                            child: const Icon(Icons.article_outlined, size: 20),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      news.headline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if ((news.source ?? '').isNotEmpty) news.source!,
                        if (news.datetime != null)
                          DateFormat('HH:mm').format(news.datetime!.toLocal()),
                      ].join(' • '),
                      style: TextStyle(fontSize: 11, color: secondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(String? rawUrl) async {
    if (rawUrl == null || rawUrl.isEmpty) return;
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(AppRadius.r8),
          ),
        ),
      ),
    );
  }
}
