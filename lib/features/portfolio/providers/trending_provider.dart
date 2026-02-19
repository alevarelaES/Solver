import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/features/portfolio/data/portfolio_cache_policy.dart';
import 'package:solver/features/portfolio/data/portfolio_trending_catalog.dart';
import 'package:solver/features/portfolio/models/company_news.dart';
import 'package:solver/features/portfolio/models/trending_stock.dart';

class MarketTrendingData {
  final List<TrendingStock> stocks;
  final List<TrendingStock> crypto;
  final MarketDataOrigin origin;

  const MarketTrendingData({
    required this.stocks,
    required this.crypto,
    this.origin = MarketDataOrigin.live,
  });
}

enum MarketDataOrigin { live, cache, fallbackCatalog }

const _trendingFreshTtl = Duration(minutes: 5);
const _trendingMaxStaleAge = Duration(hours: 4);
const _newsFreshTtl = Duration(minutes: 5);
const _newsMaxStaleAge = Duration(hours: 1);

TimedCacheEntry<MarketTrendingData>? _trendingCache;
TimedCacheEntry<List<CompanyNews>>? _marketNewsCache;

final trendingProvider = FutureProvider<MarketTrendingData>((ref) async {
  final client = ref.watch(apiClientProvider);
  if (isCacheFresh(_trendingCache, _trendingFreshTtl)) {
    return _trendingCache!.value;
  }

  try {
    final response = await client.get<Map<String, dynamic>>(
      '/api/market/trending',
    );
    final data = response.data;
    if (data == null) return _resolveTrendingFallback();

    final stockRaw = data['stocks'] as List<dynamic>? ?? const [];
    final cryptoRaw = data['crypto'] as List<dynamic>? ?? const [];

    final stocks = stockRaw
        .whereType<Map<String, dynamic>>()
        .map(TrendingStock.fromJson)
        .toList();
    final crypto = cryptoRaw
        .whereType<Map<String, dynamic>>()
        .map(TrendingStock.fromJson)
        .toList();

    if (stocks.isEmpty && crypto.isEmpty) {
      return _resolveTrendingFallback();
    }

    final live = MarketTrendingData(stocks: stocks, crypto: crypto);
    _trendingCache = TimedCacheEntry(value: live, storedAt: DateTime.now());
    return live;
  } on DioException catch (_) {
    return _resolveTrendingFallback();
  }
});

final marketNewsProvider = FutureProvider.autoDispose<List<CompanyNews>>((
  ref,
) async {
  if (isCacheFresh(_marketNewsCache, _newsFreshTtl)) {
    return _marketNewsCache!.value;
  }

  final client = ref.watch(apiClientProvider);
  try {
    final response = await client.get<Map<String, dynamic>>(
      '/api/market/news-general',
    );
    final data = response.data;
    if (data == null) return _resolveNewsFallback();
    final news = (data['news'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CompanyNews.fromJson)
        .toList(growable: false);
    if (news.isEmpty) return _resolveNewsFallback();
    _marketNewsCache = TimedCacheEntry(value: news, storedAt: DateTime.now());
    return news;
  } on DioException catch (_) {
    return _resolveNewsFallback();
  }
});

final _fallbackTrending = _buildFallbackTrending();

MarketTrendingData _buildFallbackTrending() {
  final assets = buildTrendingFallbackAssets();
  final stocks = assets
      .where((asset) => asset.assetType == 'stock')
      .toList(growable: false);
  final crypto = assets
      .where((asset) => asset.assetType == 'crypto')
      .toList(growable: false);
  return MarketTrendingData(
    stocks: stocks,
    crypto: crypto,
    origin: MarketDataOrigin.fallbackCatalog,
  );
}

MarketTrendingData _resolveTrendingFallback() {
  if (isCacheUsable(_trendingCache, _trendingMaxStaleAge)) {
    final cached = _trendingCache!.value;
    return MarketTrendingData(
      stocks: cached.stocks
          .map((item) => item.copyWith(isStale: true))
          .toList(growable: false),
      crypto: cached.crypto
          .map((item) => item.copyWith(isStale: true))
          .toList(growable: false),
      origin: MarketDataOrigin.cache,
    );
  }
  return _fallbackTrending;
}

List<CompanyNews> _resolveNewsFallback() {
  if (isCacheUsable(_marketNewsCache, _newsMaxStaleAge)) {
    return _marketNewsCache!.value;
  }
  return const [];
}
