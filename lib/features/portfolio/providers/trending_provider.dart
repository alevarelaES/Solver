import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/features/portfolio/models/company_news.dart';
import 'package:solver/features/portfolio/models/trending_stock.dart';

class MarketTrendingData {
  final List<TrendingStock> stocks;
  final List<TrendingStock> crypto;

  const MarketTrendingData({required this.stocks, required this.crypto});
}

final trendingProvider = FutureProvider<MarketTrendingData>((ref) async {
  final client = ref.watch(apiClientProvider);
  try {
    final response = await client.get<Map<String, dynamic>>(
      '/api/market/trending',
    );
    final data = response.data;
    if (data == null) return _fallbackTrending;

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

    if (stocks.isEmpty && crypto.isEmpty) return _fallbackTrending;

    return MarketTrendingData(stocks: stocks, crypto: crypto);
  } on DioException catch (_) {
    return _fallbackTrending;
  }
});

final marketNewsProvider = FutureProvider.autoDispose<List<CompanyNews>>((
  ref,
) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get<Map<String, dynamic>>(
    '/api/market/news-general',
  );
  final data = response.data;
  if (data == null) return [];
  final news = data['news'] as List<dynamic>? ?? [];
  return news
      .map((e) => CompanyNews.fromJson(e as Map<String, dynamic>))
      .toList();
});

const _fallbackTrending = MarketTrendingData(
  stocks: [
    TrendingStock(
      symbol: 'AAPL',
      name: 'Apple Inc',
      price: null,
      changePercent: null,
      currency: 'USD',
      isStale: true,
      assetType: 'stock',
    ),
    TrendingStock(
      symbol: 'MSFT',
      name: 'Microsoft Corp',
      price: null,
      changePercent: null,
      currency: 'USD',
      isStale: true,
      assetType: 'stock',
    ),
    TrendingStock(
      symbol: 'NVDA',
      name: 'NVIDIA Corp',
      price: null,
      changePercent: null,
      currency: 'USD',
      isStale: true,
      assetType: 'stock',
    ),
    TrendingStock(
      symbol: 'TSLA',
      name: 'Tesla Inc',
      price: null,
      changePercent: null,
      currency: 'USD',
      isStale: true,
      assetType: 'stock',
    ),
    TrendingStock(
      symbol: 'AMZN',
      name: 'Amazon.com Inc',
      price: null,
      changePercent: null,
      currency: 'USD',
      isStale: true,
      assetType: 'stock',
    ),
    TrendingStock(
      symbol: 'META',
      name: 'Meta Platforms',
      price: null,
      changePercent: null,
      currency: 'USD',
      isStale: true,
      assetType: 'stock',
    ),
    TrendingStock(
      symbol: 'GOOGL',
      name: 'Alphabet Inc',
      price: null,
      changePercent: null,
      currency: 'USD',
      isStale: true,
      assetType: 'stock',
    ),
    TrendingStock(
      symbol: 'NFLX',
      name: 'Netflix Inc',
      price: null,
      changePercent: null,
      currency: 'USD',
      isStale: true,
      assetType: 'stock',
    ),
    TrendingStock(
      symbol: 'AMD',
      name: 'AMD',
      price: null,
      changePercent: null,
      currency: 'USD',
      isStale: true,
      assetType: 'stock',
    ),
    TrendingStock(
      symbol: 'INTC',
      name: 'Intel Corp',
      price: null,
      changePercent: null,
      currency: 'USD',
      isStale: true,
      assetType: 'stock',
    ),
    TrendingStock(
      symbol: 'JPM',
      name: 'JPMorgan Chase',
      price: null,
      changePercent: null,
      currency: 'USD',
      isStale: true,
      assetType: 'stock',
    ),
    TrendingStock(
      symbol: 'V',
      name: 'Visa Inc',
      price: null,
      changePercent: null,
      currency: 'USD',
      isStale: true,
      assetType: 'stock',
    ),
  ],
  crypto: [
    TrendingStock(
      symbol: 'BTC/USD',
      name: 'Bitcoin',
      price: null,
      changePercent: null,
      currency: 'USD',
      isStale: true,
      assetType: 'crypto',
    ),
    TrendingStock(
      symbol: 'ETH/USD',
      name: 'Ethereum',
      price: null,
      changePercent: null,
      currency: 'USD',
      isStale: true,
      assetType: 'crypto',
    ),
    TrendingStock(
      symbol: 'SOL/USD',
      name: 'Solana',
      price: null,
      changePercent: null,
      currency: 'USD',
      isStale: true,
      assetType: 'crypto',
    ),
    TrendingStock(
      symbol: 'BNB/USD',
      name: 'BNB',
      price: null,
      changePercent: null,
      currency: 'USD',
      isStale: true,
      assetType: 'crypto',
    ),
    TrendingStock(
      symbol: 'XRP/USD',
      name: 'XRP',
      price: null,
      changePercent: null,
      currency: 'USD',
      isStale: true,
      assetType: 'crypto',
    ),
    TrendingStock(
      symbol: 'ADA/USD',
      name: 'Cardano',
      price: null,
      changePercent: null,
      currency: 'USD',
      isStale: true,
      assetType: 'crypto',
    ),
    TrendingStock(
      symbol: 'DOGE/USD',
      name: 'Dogecoin',
      price: null,
      changePercent: null,
      currency: 'USD',
      isStale: true,
      assetType: 'crypto',
    ),
    TrendingStock(
      symbol: 'AVAX/USD',
      name: 'Avalanche',
      price: null,
      changePercent: null,
      currency: 'USD',
      isStale: true,
      assetType: 'crypto',
    ),
  ],
);
