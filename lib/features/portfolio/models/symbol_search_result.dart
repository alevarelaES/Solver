class SymbolSearchResult {
  final String symbol;
  final String name;
  final String? exchange;
  final String type;
  final String? country;

  const SymbolSearchResult({
    required this.symbol,
    required this.name,
    required this.exchange,
    required this.type,
    required this.country,
  });

  factory SymbolSearchResult.fromJson(Map<String, dynamic> json) {
    return SymbolSearchResult(
      symbol: (json['symbol'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      exchange: json['exchange'] as String?,
      type: (json['type'] ?? 'stock').toString(),
      country: json['country'] as String?,
    );
  }
}
