import 'package:solver/features/portfolio/models/trending_stock.dart';

class _TrendingSeed {
  final String symbol;
  final String name;
  final String assetType;

  const _TrendingSeed({
    required this.symbol,
    required this.name,
    required this.assetType,
  });
}

const _trendingSeeds = <_TrendingSeed>[
  _TrendingSeed(symbol: 'AAPL', name: 'Apple Inc', assetType: 'stock'),
  _TrendingSeed(symbol: 'MSFT', name: 'Microsoft Corp', assetType: 'stock'),
  _TrendingSeed(symbol: 'NVDA', name: 'NVIDIA Corp', assetType: 'stock'),
  _TrendingSeed(symbol: 'AMZN', name: 'Amazon.com Inc', assetType: 'stock'),
  _TrendingSeed(symbol: 'GOOGL', name: 'Alphabet Inc', assetType: 'stock'),
  _TrendingSeed(symbol: 'META', name: 'Meta Platforms', assetType: 'stock'),
  _TrendingSeed(symbol: 'TSLA', name: 'Tesla Inc', assetType: 'stock'),
  _TrendingSeed(symbol: 'NFLX', name: 'Netflix Inc', assetType: 'stock'),
  _TrendingSeed(symbol: 'AMD', name: 'AMD', assetType: 'stock'),
  _TrendingSeed(symbol: 'INTC', name: 'Intel Corp', assetType: 'stock'),
  _TrendingSeed(symbol: 'JPM', name: 'JPMorgan Chase', assetType: 'stock'),
  _TrendingSeed(symbol: 'V', name: 'Visa Inc', assetType: 'stock'),
  _TrendingSeed(symbol: 'BTC/USD', name: 'Bitcoin', assetType: 'crypto'),
  _TrendingSeed(symbol: 'ETH/USD', name: 'Ethereum', assetType: 'crypto'),
  _TrendingSeed(symbol: 'SOL/USD', name: 'Solana', assetType: 'crypto'),
  _TrendingSeed(symbol: 'BNB/USD', name: 'BNB', assetType: 'crypto'),
  _TrendingSeed(symbol: 'XRP/USD', name: 'XRP', assetType: 'crypto'),
  _TrendingSeed(symbol: 'ADA/USD', name: 'Cardano', assetType: 'crypto'),
  _TrendingSeed(symbol: 'DOGE/USD', name: 'Dogecoin', assetType: 'crypto'),
  _TrendingSeed(symbol: 'AVAX/USD', name: 'Avalanche', assetType: 'crypto'),
];

const marketQuickSearchSymbols = <String>[
  'AAPL',
  'MSFT',
  'NVDA',
  'TSLA',
  'BTC/USD',
  'ETH/USD',
];

List<TrendingStock> buildTrendingFallbackAssets({int? limit}) {
  final source = limit == null ? _trendingSeeds : _trendingSeeds.take(limit);
  return source
      .map(
        (seed) => TrendingStock(
          symbol: seed.symbol,
          name: seed.name,
          price: null,
          changePercent: null,
          currency: 'USD',
          isStale: true,
          assetType: seed.assetType,
        ),
      )
      .toList(growable: false);
}
