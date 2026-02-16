class AnalystRecommendation {
  final String period;
  final int buy;
  final int hold;
  final int sell;
  final int strongBuy;
  final int strongSell;

  const AnalystRecommendation({
    required this.period,
    required this.buy,
    required this.hold,
    required this.sell,
    required this.strongBuy,
    required this.strongSell,
  });

  int get total => buy + hold + sell + strongBuy + strongSell;

  factory AnalystRecommendation.fromJson(Map<String, dynamic> json) {
    return AnalystRecommendation(
      period: (json['period'] ?? '').toString(),
      buy: (json['buy'] as num?)?.toInt() ?? 0,
      hold: (json['hold'] as num?)?.toInt() ?? 0,
      sell: (json['sell'] as num?)?.toInt() ?? 0,
      strongBuy: (json['strongBuy'] as num?)?.toInt() ?? 0,
      strongSell: (json['strongSell'] as num?)?.toInt() ?? 0,
    );
  }
}
