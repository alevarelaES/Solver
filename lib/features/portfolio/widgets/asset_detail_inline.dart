import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/settings/currency_settings_provider.dart';
import 'package:solver/core/services/api_client.dart';
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
import 'package:solver/features/portfolio/providers/portfolio_provider.dart';
import 'package:solver/features/portfolio/providers/price_history_provider.dart';
import 'package:solver/features/portfolio/providers/price_stream_provider.dart';
import 'package:solver/features/portfolio/providers/selected_asset_provider.dart';
import 'package:solver/features/portfolio/providers/watchlist_provider.dart';
import 'package:solver/features/portfolio/services/portfolio_transaction_bridge.dart';
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
  bool _tradeBusy = false;

  String get _assetCurrency =>
      widget.holding?.currency ?? widget.watchlistItem?.currency ?? 'USD';

  @override
  Widget build(BuildContext context) {
    final symbol = widget.symbol.toUpperCase();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;

    ref.watch(appCurrencyProvider);

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
    final canSell = widget.holding != null && widget.holding!.quantity > 0;
    final watchlistAsync = ref.watch(watchlistProvider);
    final favorites = watchlistAsync.valueOrNull ?? const <WatchlistItem>[];
    WatchlistItem? favoriteItem;
    for (final item in favorites) {
      if (item.symbol.toUpperCase() == symbol) {
        favoriteItem = item;
        break;
      }
    }
    final isFavorite = favoriteItem != null;

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
            IconButton(
              tooltip: isFavorite
                  ? 'Retirer des favoris'
                  : 'Ajouter aux favoris',
              onPressed: _tradeBusy
                  ? null
                  : () => _toggleFavorite(
                      symbol: symbol,
                      existingFavorite: favoriteItem,
                    ),
              icon: Icon(
                isFavorite ? Icons.star : Icons.star_outline,
                size: 20,
                color: isFavorite ? AppColors.warning : textPrimary,
              ),
            ),
            if (widget.onClose != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: widget.onClose,
                tooltip: 'Fermer',
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        profileAsync.when(
                  loading: () => const _LoadingBox(height: 112),
                  error: (_, _) => _HeroCard(
                    symbol: symbol,
                    profile: null,
                    currentPrice: currentPrice,
                    changePercent: changePercent,
                    flashColor: _flashColor,
                    currency: _assetCurrency,
                    onBuy: () => _startTrade(
                      action: _TradeAction.buy,
                      symbol: symbol,
                      currentPrice: currentPrice,
                      profile: null,
                    ),
                    onSell: canSell
                        ? () => _startTrade(
                            action: _TradeAction.sell,
                            symbol: symbol,
                            currentPrice: currentPrice,
                            profile: null,
                          )
                        : null,
                    tradeBusy: _tradeBusy,
                  ),
                  data: (profile) => _HeroCard(
                    symbol: symbol,
                    profile: profile,
                    currentPrice: currentPrice,
                    changePercent: changePercent,
                    flashColor: _flashColor,
                    currency: _assetCurrency,
                    onBuy: () => _startTrade(
                      action: _TradeAction.buy,
                      symbol: symbol,
                      currentPrice: currentPrice,
                      profile: profile,
                    ),
                    onSell: canSell
                        ? () => _startTrade(
                            action: _TradeAction.sell,
                            symbol: symbol,
                            currentPrice: currentPrice,
                            profile: profile,
                          )
                        : null,
                    tradeBusy: _tradeBusy,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 860;

                    final chart = _ChartPanel(
                      symbol: symbol,
                      period: _period,
                      currency: _assetCurrency,
                      onPeriodChanged: (period) {
                        setState(() => _period = period);
                      },
                    );

                    final analystWidget = recoAsync.when(
                      loading: () => const _LoadingBox(height: 100),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (recommendations) => _AnalystCard(
                        recommendation: recommendations.isEmpty
                            ? null
                            : recommendations.first,
                      ),
                    );

                    final metricsWidget = _MetricsCard(
                      history: yearHistoryAsync.valueOrNull ?? const [],
                    );

                    final hasPosition = widget.holding != null;
                    final hasOrderBook = currentPrice != null;

                    // 2×2 grid: [Analyst | Metrics] / [Position | OrderBook]
                    final side = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: analystWidget),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(child: metricsWidget),
                          ],
                        ),
                        if (hasPosition || hasOrderBook) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (hasPosition) ...[
                                Expanded(
                                  child: _PositionCard(
                                    holding: widget.holding!,
                                  ),
                                ),
                                if (hasOrderBook)
                                  const SizedBox(width: AppSpacing.sm),
                              ],
                              if (hasOrderBook)
                                Expanded(
                                  child: _OrderBookCard(
                                    symbol: symbol,
                                    currentPrice: currentPrice,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    );

                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: chart),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(flex: 2, child: side),
                        ],
                      );
                    }

                    // Narrow / mobile: stacked
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
    );
  }

  Future<void> _startTrade({
    required _TradeAction action,
    required String symbol,
    required double? currentPrice,
    required CompanyProfile? profile,
  }) async {
    if (_tradeBusy) return;
    final order = await showDialog<_TradeOrder>(
      context: context,
      builder: (_) => _TradeDialog(
        action: action,
        symbol: symbol,
        currentPrice: currentPrice,
        assetCurrency: _assetCurrency,
        maxSellValue: action == _TradeAction.sell
            ? (widget.holding?.quantity ?? 0) * (currentPrice ?? 0)
            : null,
      ),
    );
    if (!mounted || order == null) return;

    setState(() => _tradeBusy = true);
    try {
      final executionPrice =
          order.executionPrice ??
          currentPrice ??
          await _loadCurrentMarketPrice(symbol);
      if (executionPrice == null || executionPrice <= 0) {
        _showError('Prix indisponible pour executer l ordre.');
        return;
      }

      if (action == _TradeAction.buy) {
        await _applyBuyOrder(
          symbol: symbol,
          profile: profile,
          order: order,
          executionPrice: executionPrice,
        );
        await _recordTradeTransaction(
          symbol: symbol,
          action: action,
          order: order,
        );
        _showSuccess('Achat enregistre');
      } else {
        await _applySellOrder(order: order, executionPrice: executionPrice);
        await _recordTradeTransaction(
          symbol: symbol,
          action: action,
          order: order,
        );
        _showSuccess('Vente enregistree');
      }
    } on DioException catch (e) {
      _showError(_extractApiError(e.response?.data));
    } catch (_) {
      _showError('Operation impossible pour le moment.');
    } finally {
      if (mounted) {
        setState(() => _tradeBusy = false);
      }
    }
  }

  Future<void> _applyBuyOrder({
    required String symbol,
    required CompanyProfile? profile,
    required _TradeOrder order,
    required double executionPrice,
  }) async {
    final quantityDelta = order.amount / executionPrice;
    if (quantityDelta <= 0) {
      throw Exception('Invalid quantity');
    }

    final mutation = ref.read(portfolioMutationsProvider);
    final existing = _resolveExistingHolding(symbol);
    if (existing != null) {
      final oldQty = existing.quantity;
      final oldAvg = existing.averageBuyPrice ?? executionPrice;
      final oldCost = oldAvg * oldQty;
      final newCost = executionPrice * quantityDelta;
      final nextQty = oldQty + quantityDelta;
      final nextAvg = nextQty > 0 ? (oldCost + newCost) / nextQty : oldAvg;

      await mutation.updateHolding(
        existing.id,
        UpdateHoldingRequest(
          name: existing.name,
          quantity: nextQty,
          averageBuyPrice: nextAvg,
          buyDate: order.tradeDate ?? existing.buyDate,
          notes: existing.notes,
        ),
      );
      return;
    }

    final assetType = widget.watchlistItem?.assetType ?? 'stock';
    final exchange = widget.watchlistItem?.exchange ?? profile?.exchange;
    final name = profile?.name ?? widget.watchlistItem?.name ?? symbol;
    final currency = widget.watchlistItem?.currency ?? 'USD';
    await mutation.addHolding(
      AddHoldingRequest(
        symbol: symbol,
        exchange: exchange,
        name: name,
        assetType: assetType,
        quantity: quantityDelta,
        averageBuyPrice: executionPrice,
        buyDate: order.tradeDate,
        currency: currency,
        notes: null,
      ),
    );
  }

  Holding? _resolveExistingHolding(String symbol) {
    final fromWidget = widget.holding;
    if (fromWidget != null &&
        fromWidget.symbol.toUpperCase() == symbol.toUpperCase()) {
      return fromWidget;
    }

    final portfolioData = ref.read(portfolioProvider).valueOrNull;
    if (portfolioData == null) return null;
    for (final holding in portfolioData.holdings) {
      if (holding.symbol.toUpperCase() == symbol.toUpperCase() &&
          !holding.isArchived &&
          holding.quantity > 0) {
        return holding;
      }
    }
    return null;
  }

  Future<void> _recordTradeTransaction({
    required String symbol,
    required _TradeAction action,
    required _TradeOrder order,
  }) async {
    try {
      await PortfolioTransactionBridge.recordTrade(
        ref: ref,
        tradeType: action == _TradeAction.buy
            ? PortfolioTradeType.buy
            : PortfolioTradeType.sell,
        symbol: symbol,
        amount: order.amount,
        tradeDate: order.tradeDate,
      );
    } catch (_) {
      _showWarning('Position mise a jour, mais transaction finance non creee.');
    }
  }

  Future<double?> _loadCurrentMarketPrice(String symbol) async {
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get<Map<String, dynamic>>(
        '/api/market/quote',
        queryParameters: {'symbols': symbol},
      );
      final quoteMap =
          response.data?['quotes'] as Map<String, dynamic>? ?? const {};

      Map<String, dynamic>? payload;
      for (final entry in quoteMap.entries) {
        if (entry.key.toUpperCase() != symbol.toUpperCase()) continue;
        if (entry.value is Map<String, dynamic>) {
          payload = entry.value as Map<String, dynamic>;
          break;
        }
      }
      if (payload == null && quoteMap.isNotEmpty) {
        final first = quoteMap.values.first;
        if (first is Map<String, dynamic>) {
          payload = first;
        }
      }

      return _asDouble(payload?['price']);
    } catch (_) {
      return null;
    }
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Future<void> _applySellOrder({
    required _TradeOrder order,
    required double executionPrice,
  }) async {
    final existing = widget.holding;
    if (existing == null) {
      throw Exception('No holding');
    }

    final quantityDelta = order.amount / executionPrice;
    if (quantityDelta <= 0) {
      throw Exception('Invalid quantity');
    }

    final mutation = ref.read(portfolioMutationsProvider);
    final nextQty = existing.quantity - quantityDelta;
    // Treat as full sell if remaining quantity is negligible (handles CHF/USD rounding)
    if (nextQty <= 1e-4) {
      await mutation.deleteHolding(existing.id);
      ref.read(selectedAssetProvider.notifier).state = null;
      return;
    }
    await mutation.updateHolding(
      existing.id,
      UpdateHoldingRequest(
        name: existing.name,
        quantity: nextQty,
        averageBuyPrice: existing.averageBuyPrice,
        buyDate: existing.buyDate,
        notes: existing.notes,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.danger,
      ),
    );
  }

  void _showWarning(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.warning,
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
    }
    return 'Operation impossible pour le moment.';
  }

  Future<void> _toggleFavorite({
    required String symbol,
    required WatchlistItem? existingFavorite,
  }) async {
    try {
      final watchlistMutations = ref.read(watchlistMutationsProvider);
      if (existingFavorite != null) {
        await watchlistMutations.remove(existingFavorite.id);
        _showSuccess('Retire des favoris');
        return;
      }

      await watchlistMutations.add(
        AddWatchlistRequest(
          symbol: symbol,
          exchange: widget.holding?.exchange ?? widget.watchlistItem?.exchange,
          name: widget.holding?.name ?? widget.watchlistItem?.name ?? symbol,
          assetType:
              widget.holding?.assetType ??
              widget.watchlistItem?.assetType ??
              'stock',
        ),
      );
      _showSuccess('Ajoute aux favoris');
    } on DioException catch (e) {
      _showError(_extractApiError(e.response?.data));
    } catch (_) {
      _showError('Operation impossible pour le moment.');
    }
  }
}

class _HeroCard extends StatelessWidget {
  final String symbol;
  final CompanyProfile? profile;
  final double? currentPrice;
  final double? changePercent;
  final Color? flashColor;
  final VoidCallback? onBuy;
  final VoidCallback? onSell;
  final bool tradeBusy;
  final String currency;

  const _HeroCard({
    required this.symbol,
    required this.profile,
    required this.currentPrice,
    required this.changePercent,
    required this.flashColor,
    required this.onBuy,
    required this.onSell,
    required this.tradeBusy,
    this.currency = 'USD',
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
          ? AppColors.portfolioSurfaceDark
          : AppColors.portfolioSurfaceLight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AssetLogo(
            symbol: symbol,
            assetType: 'stock',
            logoUrl: profile?.logo,
            size: 44,
            borderRadius: AppRadius.md,
          ),
          const SizedBox(width: AppSpacing.lg),
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
                        fontSize: 30,
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
                const SizedBox(height: AppSpacing.s6),
                Text(
                  profile?.name ?? symbol,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: AppSpacing.s6),
                Text(
                  [
                    if ((profile?.sector ?? '').isNotEmpty) profile!.sector!,
                    if ((profile?.country ?? '').isNotEmpty) profile!.country!,
                  ].join(' • '),
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: GoogleFonts.robotoMono(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: flashColor ?? Theme.of(context).colorScheme.onSurface,
                ),
                child: Text(
                  AppFormats.formatFromCurrency(currentPrice, currency),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                changePercent == null
                    ? '--'
                    : '${up ? '+' : ''}${changePercent!.toStringAsFixed(2)}%',
                style: TextStyle(
                  color: trendColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              if (profile?.marketCap != null)
                Text(
                  'MCap ${_formatMarketCap(profile!.marketCap!)}',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: tradeBusy ? null : onBuy,
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.add_shopping_cart, size: 14),
                    label: const Text('Acheter'),
                  ),
                  if (onSell != null)
                    OutlinedButton.icon(
                      onPressed: tradeBusy ? null : onSell,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        backgroundColor: AppColors.danger.withValues(
                          alpha: 0.08,
                        ),
                        side: BorderSide(
                          color: AppColors.danger.withValues(alpha: 0.4),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.sell, size: 14),
                      label: const Text('Vendre'),
                    ),
                ],
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
  final String currency;

  const _ChartPanel({
    required this.symbol,
    required this.period,
    required this.onPeriodChanged,
    this.currency = 'USD',
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartHeight = constraints.maxWidth < 980
            ? 320.0
            : constraints.maxWidth < 1320
            ? 360.0
            : 420.0;

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
                  PriceChartPeriodBar(
                    selected: period,
                    onChanged: onPeriodChanged,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: chartHeight,
                child: PriceChart(
                  symbol: symbol,
                  period: period,
                  height: chartHeight,
                  framed: false,
                  currencyCode: currency,
                ),
              ),
            ],
          ),
        );
      },
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                sentiment,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: sentimentColor,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                total == 0
                    ? 'Pas assez de votes'
                    : '${(buyRatio * 100).toStringAsFixed(0)}% positif',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            total == 0
                ? ''
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
            value: current == null ? '--' : current.toStringAsFixed(2),
          ),
          _MetricRow(
            label: 'Plus haut 52 sem.',
            value: high == null ? '--' : high.toStringAsFixed(2),
          ),
          _MetricRow(
            label: 'Plus bas 52 sem.',
            value: low == null ? '--' : low.toStringAsFixed(2),
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

class _PositionCard extends ConsumerWidget {
  final Holding holding;

  const _PositionCard({required this.holding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appCurrencyProvider);
    final rawInvested = (holding.averageBuyPrice ?? 0) * holding.quantity;

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
            value: AppFormats.formatFromCurrency(rawInvested, holding.currency),
          ),
          _MetricRow(
            label: 'Valeur',
            value: AppFormats.formatFromCurrency(holding.totalValue, holding.currency),
          ),
          _MetricRow(
            label: 'Gain / Perte',
            value: AppFormats.formatFromCurrency(holding.totalGainLoss, holding.currency),
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
    final secondary = Theme.of(context).brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    const sectionStyle = TextStyle(
      fontSize: 9,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.0,
    );

    return AppPanel(
      variant: AppPanelVariant.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'CARNET D\'ORDRES',
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
          Row(
            children: [
              Text('Prix', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: secondary)),
              const Spacer(),
              Text('Quantité', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: secondary)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('VENTE', style: sectionStyle.copyWith(color: AppColors.danger)),
          const SizedBox(height: 2),
          ...asks.map(
            (l) => _OrderRow(
              price: l.price,
              volume: l.volume,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('ACHAT', style: sectionStyle.copyWith(color: AppColors.success)),
          const SizedBox(height: 2),
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
              const Text(
                'MARKET INTELLIGENCE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final crossCount = width > 1320
                      ? 3
                      : width > 860
                      ? 2
                      : 1;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossCount,
                      mainAxisSpacing: AppSpacing.md,
                      crossAxisSpacing: AppSpacing.md,
                      childAspectRatio: crossCount == 1 ? 4.2 : 3.4,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) =>
                        _NewsCard(news: items[index]),
                  );
                },
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
    final secondary = Theme.of(context).brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return InkWell(
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
                child: kIsWeb || (news.image ?? '').isEmpty
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
                    ].join(' - '),
                    style: TextStyle(fontSize: 11, color: secondary),
                  ),
                ],
              ),
            ),
          ],
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

enum _TradeAction { buy, sell }

class _TradeOrder {
  final double amount;
  final double? executionPrice;
  final DateTime? tradeDate;

  const _TradeOrder({
    required this.amount,
    required this.executionPrice,
    required this.tradeDate,
  });
}

class _TradeDialog extends StatefulWidget {
  final _TradeAction action;
  final String symbol;
  final double? currentPrice;
  final double? maxSellValue;
  final String assetCurrency;

  const _TradeDialog({
    required this.action,
    required this.symbol,
    required this.currentPrice,
    required this.maxSellValue,
    this.assetCurrency = 'USD',
  });

  @override
  State<_TradeDialog> createState() => _TradeDialogState();
}

class _TradeDialogState extends State<_TradeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  DateTime? _tradeDate;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBuy = widget.action == _TradeAction.buy;
    final title = isBuy
        ? 'Acheter ${widget.symbol}'
        : 'Vendre ${widget.symbol}';

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  isBuy
                      ? 'Entrez le montant que vous voulez investir.'
                      : 'Entrez le montant que vous voulez retirer.',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: isBuy
                        ? 'Montant a investir'
                        : 'Montant a vendre',
                    helperText:
                        widget.maxSellValue != null &&
                            widget.maxSellValue! > 0 &&
                            !isBuy
                        ? 'Max env. ${AppFormats.formatFromCurrency(widget.maxSellValue, widget.assetCurrency)}'
                        : null,
                  ),
                  validator: (value) {
                    final amount = _parseDouble(value);
                    if (amount == null || amount <= 0) {
                      return 'Montant invalide';
                    }
                    return null;
                  },
                ),
                if (!isBuy &&
                    widget.maxSellValue != null &&
                    widget.maxSellValue! > 0) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ActionChip(
                      backgroundColor: AppColors.danger.withValues(alpha: 0.1),
                      side: BorderSide(
                        color: AppColors.danger.withValues(alpha: 0.35),
                      ),
                      labelStyle: const TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                      ),
                      label: Text(
                        'Utiliser le total: ${AppFormats.formatFromCurrency(widget.maxSellValue, widget.assetCurrency)}',
                      ),
                      onPressed: () {
                        _amountCtrl.text = widget.maxSellValue!.toStringAsFixed(
                          2,
                        );
                        setState(() {});
                      },
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Prix manuel (optionnel)',
                    helperText: 'Laisser vide pour utiliser le prix actuel.',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                InkWell(
                  onTap: _pickTradeDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date (optionnel)',
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(
                      _tradeDate == null
                          ? 'Aujourd hui'
                          : DateFormat('dd/MM/yyyy').format(_tradeDate!),
                    ),
                  ),
                ),
                if (widget.currentPrice != null &&
                    widget.currentPrice! > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Prix actuel: ${widget.currentPrice!.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ElevatedButton(
                      onPressed: _submit,
                      style: isBuy
                          ? null
                          : ElevatedButton.styleFrom(
                              elevation: 0,
                              foregroundColor: AppColors.danger,
                              backgroundColor: AppColors.danger.withValues(
                                alpha: 0.12,
                              ),
                              side: BorderSide(
                                color: AppColors.danger.withValues(alpha: 0.35),
                              ),
                            ),
                      child: Text(isBuy ? 'Acheter' : 'Vendre'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickTradeDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _tradeDate ?? now,
      firstDate: DateTime(1980, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null) {
      setState(() => _tradeDate = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final amount = _parseDouble(_amountCtrl.text);
    if (amount == null || amount <= 0) return;

    if (widget.action == _TradeAction.sell &&
        widget.maxSellValue != null &&
        widget.maxSellValue! > 0 &&
        amount > widget.maxSellValue! * 1.1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Montant de vente trop eleve pour cette position.'),
        ),
      );
      return;
    }

    final price = _parseDouble(_priceCtrl.text);
    Navigator.of(context).pop(
      _TradeOrder(amount: amount, executionPrice: price, tradeDate: _tradeDate),
    );
  }

  double? _parseDouble(String? raw) {
    final normalized = (raw ?? '').trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
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
            color: isDark ? Colors.white10 : AppColors.borderLight,
            borderRadius: BorderRadius.circular(AppRadius.r8),
          ),
        ),
      ),
    );
  }
}
