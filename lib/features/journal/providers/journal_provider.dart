import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/features/transactions/models/transaction.dart';

class JournalFilters {
  final String? accountId;
  final String? status; // null = all, 'completed', 'pending'
  final int year;
  final int? month; // null = all months
  final bool showFuture;

  const JournalFilters({
    this.accountId,
    this.status,
    required this.year,
    this.month,
    this.showFuture = false,
  });

  JournalFilters copyWith({
    Object? accountId = _sentinel,
    Object? status = _sentinel,
    int? year,
    Object? month = _sentinel,
    bool? showFuture,
  }) => JournalFilters(
    accountId: accountId == _sentinel ? this.accountId : accountId as String?,
    status: status == _sentinel ? this.status : status as String?,
    year: year ?? this.year,
    month: month == _sentinel ? this.month : month as int?,
    showFuture: showFuture ?? this.showFuture,
  );
}

const _sentinel = Object();

final journalFiltersProvider = StateProvider<JournalFilters>(
  (ref) => JournalFilters(year: DateTime.now().year),
);

final _journalQueryScopeProvider = Provider<({int year, bool showFuture})>((ref) {
  final filters = ref.watch(journalFiltersProvider);
  return (year: filters.year, showFuture: filters.showFuture);
});

final journalTransactionsProvider = FutureProvider<List<Transaction>>((
  ref,
) async {
  final scope = ref.watch(_journalQueryScopeProvider);
  final client = ref.watch(apiClientProvider);

  final params = <String, dynamic>{
    'year': scope.year,
    'showFuture': scope.showFuture,
    // Big enough to apply account/month/status filters locally without refetch.
    'pageSize': 2000,
  };

  final response = await client.get<Map<String, dynamic>>(
    '/api/transactions',
    queryParameters: params,
  );
  final data = response.data as Map<String, dynamic>;
  return (data['items'] as List)
      .map((t) => Transaction.fromJson(t as Map<String, dynamic>))
      .toList();
});
