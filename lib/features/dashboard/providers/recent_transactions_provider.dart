import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/features/transactions/models/transaction.dart';

/// Fetches the 10 most recent transactions (all accounts, sorted by date desc).
final recentTransactionsProvider = FutureProvider.autoDispose<List<Transaction>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final now = DateTime.now();

  final response = await client.get<Map<String, dynamic>>(
    '/api/transactions',
    queryParameters: {
      'year': now.year,
      'pageSize': 10,
      'page': 1,
    },
  );
  final data = response.data as Map<String, dynamic>;
  final items = (data['items'] as List)
      .map((t) => Transaction.fromJson(t as Map<String, dynamic>))
      .toList();

  // Sort by date descending (most recent first)
  items.sort((a, b) => b.date.compareTo(a.date));
  return items;
});
