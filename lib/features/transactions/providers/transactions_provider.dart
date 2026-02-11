import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/features/transactions/models/transaction.dart';

// Key: (accountId, month, year)
typedef TransactionKey = ({String accountId, int month, int year});

final transactionsByAccountMonthProvider =
    FutureProvider.family<List<Transaction>, TransactionKey>((ref, key) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get<Map<String, dynamic>>(
    '/api/transactions',
    queryParameters: {
      'accountId': key.accountId,
      'month': key.month,
      'year': key.year,
      'showFuture': true,
      'pageSize': 100,
    },
  );
  final data = response.data as Map<String, dynamic>;
  return (data['items'] as List)
      .map((t) => Transaction.fromJson(t as Map<String, dynamic>))
      .toList();
});
