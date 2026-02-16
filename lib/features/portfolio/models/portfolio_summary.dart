import 'package:solver/features/portfolio/models/holding.dart';

class PortfolioSummary {
  final double totalValue;
  final double totalInvested;
  final double totalGainLoss;
  final double totalGainLossPercent;
  final int holdingsCount;

  const PortfolioSummary({
    required this.totalValue,
    required this.totalInvested,
    required this.totalGainLoss,
    required this.totalGainLossPercent,
    required this.holdingsCount,
  });

  factory PortfolioSummary.fromJson(Map<String, dynamic> json) {
    return PortfolioSummary(
      totalValue: _asDouble(json['totalValue']) ?? 0,
      totalInvested: _asDouble(json['totalInvested']) ?? 0,
      totalGainLoss: _asDouble(json['totalGainLoss']) ?? 0,
      totalGainLossPercent: _asDouble(json['totalGainLossPercent']) ?? 0,
      holdingsCount: (json['holdingsCount'] as num?)?.toInt() ?? 0,
    );
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

class PortfolioData {
  final List<Holding> holdings;
  final PortfolioSummary summary;

  const PortfolioData({required this.holdings, required this.summary});

  factory PortfolioData.fromJson(Map<String, dynamic> json) {
    final rawHoldings = json['holdings'] as List<dynamic>? ?? const [];
    final summaryMap = json['summary'] as Map<String, dynamic>? ?? const {};

    return PortfolioData(
      holdings: rawHoldings
          .whereType<Map<String, dynamic>>()
          .map(Holding.fromJson)
          .toList(),
      summary: PortfolioSummary.fromJson(summaryMap),
    );
  }
}
