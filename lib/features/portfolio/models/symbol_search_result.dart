class SymbolSearchResult {
  final String symbol;
  final String name;
  final String? exchange;
  final String type;
  final String? country;
  final double? lastPrice;
  final String? currency;

  const SymbolSearchResult({
    required this.symbol,
    required this.name,
    required this.exchange,
    required this.type,
    required this.country,
    this.lastPrice,
    this.currency,
  });

  factory SymbolSearchResult.fromJson(Map<String, dynamic> json) {
    return SymbolSearchResult(
      symbol: (json['symbol'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      exchange: json['exchange'] as String?,
      type: (json['type'] ?? 'stock').toString(),
      country: json['country'] as String?,
      lastPrice: _toDouble(json['lastPrice'] ?? json['price']),
      currency: json['currency'] as String?,
    );
  }

  SymbolSearchResult copyWith({
    String? symbol,
    String? name,
    String? exchange,
    String? type,
    String? country,
    double? lastPrice,
    String? currency,
  }) {
    return SymbolSearchResult(
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      exchange: exchange ?? this.exchange,
      type: type ?? this.type,
      country: country ?? this.country,
      lastPrice: lastPrice ?? this.lastPrice,
      currency: currency ?? this.currency,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
