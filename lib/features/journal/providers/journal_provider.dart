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

final journalSearchProvider = StateProvider<String>((ref) => '');

class JournalColumnFilters {
  final DateTime? fromDate;
  final DateTime? toDate;
  final String label;
  final double? minAmount;
  final double? maxAmount;

  const JournalColumnFilters({
    this.fromDate,
    this.toDate,
    this.label = '',
    this.minAmount,
    this.maxAmount,
  });

  bool get hasActiveFilters =>
      fromDate != null ||
      toDate != null ||
      label.trim().isNotEmpty ||
      minAmount != null ||
      maxAmount != null;

  JournalColumnFilters copyWith({
    Object? fromDate = _sentinel,
    Object? toDate = _sentinel,
    String? label,
    Object? minAmount = _sentinel,
    Object? maxAmount = _sentinel,
  }) => JournalColumnFilters(
    fromDate: fromDate == _sentinel ? this.fromDate : fromDate as DateTime?,
    toDate: toDate == _sentinel ? this.toDate : toDate as DateTime?,
    label: label ?? this.label,
    minAmount: minAmount == _sentinel ? this.minAmount : minAmount as double?,
    maxAmount: maxAmount == _sentinel ? this.maxAmount : maxAmount as double?,
  );
}

final journalColumnFiltersProvider = StateProvider<JournalColumnFilters>(
  (ref) => const JournalColumnFilters(),
);

final _journalQueryScopeProvider =
    Provider<
      ({
        String? accountId,
        String? status,
        int year,
        int month,
        bool showFuture,
        String search,
      })
    >((ref) {
      final filters = ref.watch(journalFiltersProvider);
      final search = ref.watch(journalSearchProvider).trim();
      final now = DateTime.now();
      final effectiveMonth =
          filters.month ?? (filters.year == now.year ? now.month : 1);

      return (
        accountId: filters.accountId,
        status: filters.status,
        year: filters.year,
        month: effectiveMonth,
        showFuture: filters.showFuture,
        search: search,
      );
    });

final journalTransactionsProvider = FutureProvider<List<Transaction>>((
  ref,
) async {
  final scope = ref.watch(_journalQueryScopeProvider);
  final client = ref.watch(apiClientProvider);

  final params = <String, dynamic>{
    'year': scope.year,
    'month': scope.month,
    'showFuture': scope.showFuture,
    'page': 1,
    'pageSize': 2000,
  };
  if (scope.accountId != null) params['accountId'] = scope.accountId;
  if (scope.status != null) params['status'] = scope.status;
  if (scope.search.isNotEmpty) params['search'] = scope.search;

  final response = await client.get<Map<String, dynamic>>(
    '/api/transactions',
    queryParameters: params,
  );
  final data = response.data as Map<String, dynamic>;
  return (data['items'] as List)
      .map((t) => Transaction.fromJson(t as Map<String, dynamic>))
      .toList();
});

final journalVisibleTransactionsProvider =
    Provider<AsyncValue<List<Transaction>>>((ref) {
      final remote = ref.watch(journalTransactionsProvider);
      final columnFilters = ref.watch(journalColumnFiltersProvider);

      if (!columnFilters.hasActiveFilters) {
        return remote;
      }

      return remote.whenData(
        (items) => items
            .where((tx) => _matchesColumnFilters(tx, columnFilters))
            .toList(growable: false),
      );
    });

bool _matchesColumnFilters(Transaction tx, JournalColumnFilters filters) {
  if (!_matchesDateFilter(tx.date, filters)) return false;

  final query = filters.label.trim().toLowerCase();
  if (query.isNotEmpty) {
    final fallback = (tx.accountName ?? tx.accountId).trim();
    final candidate =
        ((tx.note ?? '').trim().isNotEmpty ? tx.note!.trim() : fallback)
            .toLowerCase();
    if (!candidate.contains(query)) return false;
  }

  final amount = tx.amount.abs();
  if (filters.minAmount != null && amount < filters.minAmount!) return false;
  if (filters.maxAmount != null && amount > filters.maxAmount!) return false;

  return true;
}

bool _matchesDateFilter(DateTime value, JournalColumnFilters filters) {
  final date = DateTime(value.year, value.month, value.day);
  final from = filters.fromDate == null
      ? null
      : DateTime(
          filters.fromDate!.year,
          filters.fromDate!.month,
          filters.fromDate!.day,
        );
  final to = filters.toDate == null
      ? null
      : DateTime(
          filters.toDate!.year,
          filters.toDate!.month,
          filters.toDate!.day,
        );

  if (from != null && date.isBefore(from)) return false;
  if (to != null && date.isAfter(to)) return false;
  return true;
}
