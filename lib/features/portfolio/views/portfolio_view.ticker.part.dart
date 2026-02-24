part of 'portfolio_view.dart';

class _MarketTickerTape extends ConsumerStatefulWidget {
  const _MarketTickerTape();

  @override
  ConsumerState<_MarketTickerTape> createState() => _MarketTickerTapeState();
}

class _MarketTickerTapeState extends ConsumerState<_MarketTickerTape> {
  late final ScrollController _controller;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    _autoTimer = Timer.periodic(const Duration(milliseconds: 35), (_) {
      if (!_controller.hasClients) return;
      final max = _controller.position.maxScrollExtent;
      if (max <= 0) return;
      final resetPoint = max / 2;
      final next = _controller.offset + 1.2;
      if (next >= resetPoint) {
        _controller.jumpTo(0);
      } else {
        _controller.jumpTo(next);
      }
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  List<TrendingStock> _buildTapeItems(MarketTrendingData market) {
    final unique = <String, TrendingStock>{};
    for (final item in [...market.stocks, ...market.crypto]) {
      final symbol = item.symbol.trim().toUpperCase();
      if (symbol.isEmpty) continue;
      unique.putIfAbsent(symbol, () => item);
    }

    // Only loop if we have items with real prices — no fallback seeds (they have no prices)
    final withPrice = unique.values.where((s) => s.price != null).toList();
    if (withPrice.isEmpty) return const [];

    // Pad to at least 20 for a seamless loop
    final items = List<TrendingStock>.from(withPrice);
    if (items.length < 20) {
      var i = 0;
      while (items.length < 20) {
        items.add(withPrice[i % withPrice.length]);
        i++;
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    ref.watch(appCurrencyProvider);
    final trendingAsync = ref.watch(trendingProvider);

    return trendingAsync.when(
      loading: () => const SizedBox(
        height: 44,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (market) {
        final items = _buildTapeItems(market);
        if (items.isEmpty) return const SizedBox.shrink();
        final loopedItems = [...items, ...items];

        return AppPanel(
          variant: AppPanelVariant.elevated,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: SizedBox(
            height: 44,
            child: ListView.separated(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: loopedItems.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, index) {
                final item = loopedItems[index];
                final pct = item.changePercent ?? 0;
                final up = pct >= 0;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Row(
                    children: [
                      AssetLogo(
                        symbol: item.symbol,
                        assetType: item.assetType,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.symbol,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppFormats.formatFromCurrency(item.price, item.currency),
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.changePercent == null
                            ? '--'
                            : '${up ? '+' : ''}${pct.toStringAsFixed(2)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: up ? AppColors.success : AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
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

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _LoadingBox(height: 44),
        SizedBox(height: AppSpacing.lg),
        _LoadingBox(height: 100),
        SizedBox(height: AppSpacing.lg),
        Expanded(child: _LoadingBox()),
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
            color: isDark ? Colors.white10 : AppColors.borderLight,
            borderRadius: BorderRadius.circular(AppRadius.r8),
          ),
        ),
      ),
    );
  }
}
