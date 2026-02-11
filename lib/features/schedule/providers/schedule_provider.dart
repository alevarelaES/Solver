import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/features/transactions/models/transaction.dart';

class UpcomingData {
  final List<Transaction> auto;
  final List<Transaction> manual;
  final double totalAuto;
  final double totalManual;
  final double grandTotal;

  const UpcomingData({
    required this.auto,
    required this.manual,
    required this.totalAuto,
    required this.totalManual,
    required this.grandTotal,
  });

  factory UpcomingData.fromJson(Map<String, dynamic> json) => UpcomingData(
        auto: (json['auto'] as List)
            .map((t) => Transaction.fromJson(t as Map<String, dynamic>))
            .toList(),
        manual: (json['manual'] as List)
            .map((t) => Transaction.fromJson(t as Map<String, dynamic>))
            .toList(),
        totalAuto: (json['totalAuto'] as num).toDouble(),
        totalManual: (json['totalManual'] as num).toDouble(),
        grandTotal: (json['grandTotal'] as num).toDouble(),
      );
}

final upcomingTransactionsProvider = FutureProvider<UpcomingData>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get<Map<String, dynamic>>('/api/transactions/upcoming');
  return UpcomingData.fromJson(response.data as Map<String, dynamic>);
});
