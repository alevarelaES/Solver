class Holding {
  final String id;
  final String symbol;
  final String? name;
  final String? exchange;
  final String assetType;
  final double quantity;
  final double? averageBuyPrice;
  final DateTime? buyDate;
  final String currency;
  final String? notes;
  final double? currentPrice;
  final double? changePercent;
  final double? totalValue;
  final double? totalGainLoss;
  final double? totalGainLossPercent;
  final bool isStale;
  final bool isArchived;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Holding({
    required this.id,
    required this.symbol,
    required this.name,
    required this.exchange,
    required this.assetType,
    required this.quantity,
    required this.averageBuyPrice,
    required this.buyDate,
    required this.currency,
    required this.notes,
    required this.currentPrice,
    required this.changePercent,
    required this.totalValue,
    required this.totalGainLoss,
    required this.totalGainLossPercent,
    required this.isStale,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Holding.fromJson(Map<String, dynamic> json) {
    return Holding(
      id: (json['id'] ?? '').toString(),
      symbol: (json['symbol'] ?? '').toString(),
      name: json['name'] as String?,
      exchange: json['exchange'] as String?,
      assetType: (json['assetType'] ?? 'stock').toString(),
      quantity: _asDouble(json['quantity']) ?? 0,
      averageBuyPrice: _asDouble(json['averageBuyPrice']),
      buyDate: _asDate(json['buyDate']),
      currency: (json['currency'] ?? 'USD').toString(),
      notes: json['notes'] as String?,
      currentPrice: _asDouble(json['currentPrice']),
      changePercent: _asDouble(json['changePercent']),
      totalValue: _asDouble(json['totalValue']),
      totalGainLoss: _asDouble(json['totalGainLoss']),
      totalGainLossPercent: _asDouble(json['totalGainLossPercent']),
      isStale: json['isStale'] as bool? ?? false,
      isArchived: json['isArchived'] as bool? ?? false,
      createdAt: _asDate(json['createdAt']),
      updatedAt: _asDate(json['updatedAt']),
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
