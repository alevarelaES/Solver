class TrendingStock {
  final String symbol;
  final String? name;
  final double? price;
  final double? changePercent;
  final String currency;
  final bool isStale;

  const TrendingStock({
    required this.symbol,
    required this.name,
    required this.price,
    required this.changePercent,
    required this.currency,
    required this.isStale,
  });

  factory TrendingStock.fromJson(Map<String, dynamic> json) {
    return TrendingStock(
      symbol: (json['symbol'] ?? '').toString(),
      name: json['name'] as String?,
      price: _asDouble(json['price']),
      changePercent: _asDouble(json['changePercent']),
      currency: (json['currency'] ?? 'USD').toString(),
      isStale: json['isStale'] as bool? ?? false,
    );
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
