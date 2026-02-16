class WatchlistItem {
  final String id;
  final String symbol;
  final String? name;
  final String? exchange;
  final String assetType;
  final int sortOrder;
  final double? currentPrice;
  final double? changePercent;
  final String currency;
  final bool isStale;
  final DateTime? createdAt;

  const WatchlistItem({
    required this.id,
    required this.symbol,
    required this.name,
    required this.exchange,
    required this.assetType,
    required this.sortOrder,
    required this.currentPrice,
    required this.changePercent,
    required this.currency,
    required this.isStale,
    required this.createdAt,
  });

  factory WatchlistItem.fromJson(Map<String, dynamic> json) {
    return WatchlistItem(
      id: (json['id'] ?? '').toString(),
      symbol: (json['symbol'] ?? '').toString(),
      name: json['name'] as String?,
      exchange: json['exchange'] as String?,
      assetType: (json['assetType'] ?? 'stock').toString(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      currentPrice: _asDouble(json['currentPrice']),
      changePercent: _asDouble(json['changePercent']),
      currency: (json['currency'] ?? 'USD').toString(),
      isStale: json['isStale'] as bool? ?? false,
      createdAt: _asDate(json['createdAt']),
    );
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _asDate(dynamic value) {
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }
}
