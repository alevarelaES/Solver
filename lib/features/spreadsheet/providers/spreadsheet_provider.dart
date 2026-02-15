import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/features/dashboard/models/dashboard_data.dart';
import 'package:solver/features/dashboard/providers/dashboard_provider.dart';
import 'package:solver/features/transactions/models/transaction.dart';

final spreadsheetYearProvider = StateProvider<int>(
  (ref) => DateTime.now().year,
);

enum SpreadsheetProjectionMode { prudent, prevision }

final spreadsheetProjectionModeProvider =
    StateProvider<SpreadsheetProjectionMode>((ref) {
      return SpreadsheetProjectionMode.prudent;
    });

final spreadsheetDataProvider = FutureProvider<SpreadsheetData>((ref) async {
  final year = ref.watch(spreadsheetYearProvider);
  final dashboard = await ref.watch(dashboardDataProvider(year).future);

  final client = ref.watch(apiClientProvider);
  final transactions = await _fetchTransactionsForYear(client, year);

  return SpreadsheetData.fromDashboard(
    dashboard,
    transactions: transactions,
    year: year,
  );
});

Future<List<Transaction>> _fetchTransactionsForYear(
  ApiClient client,
  int year,
) async {
  const pageSize = 500;
  const maxPages = 80;

  final items = <Transaction>[];

  for (var page = 1; page <= maxPages; page++) {
    final response = await client.get<Map<String, dynamic>>(
      '/api/transactions',
      queryParameters: {
        'year': year,
        'showFuture': true,
        'page': page,
        'pageSize': pageSize,
      },
    );

    final data = response.data as Map<String, dynamic>;
    final rawItems = (data['items'] as List? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();

    if (rawItems.isEmpty) break;

    items.addAll(rawItems.map(Transaction.fromJson));

    final totalPagesRaw = data['totalPages'];
    if (totalPagesRaw is int && page >= totalPagesRaw) {
      break;
    }

    if (rawItems.length < pageSize) {
      break;
    }
  }

  return items;
}

class SpreadsheetData {
  final int year;
  final List<SpreadsheetSection> sections;

  const SpreadsheetData({required this.year, required this.sections});

  factory SpreadsheetData.fromDashboard(
    DashboardData dashboard, {
    required List<Transaction> transactions,
    required int year,
  }) {
    final monthlyByAccount = <String, List<SpreadsheetMonthValue>>{};

    for (final tx in transactions) {
      if (tx.date.year != year) continue;

      final monthIndex = tx.date.month - 1;
      if (monthIndex < 0 || monthIndex > 11) continue;

      final months = monthlyByAccount.putIfAbsent(
        tx.accountId,
        () => List<SpreadsheetMonthValue>.generate(
          12,
          (_) => const SpreadsheetMonthValue.zero(),
        ),
      );

      final current = months[monthIndex];
      final amount = tx.amount.abs();

      months[monthIndex] = tx.isCompleted
          ? current.copyWith(completed: current.completed + amount)
          : current.copyWith(pending: current.pending + amount);
    }

    final sections = <SpreadsheetSection>[];

    for (var i = 0; i < dashboard.groups.length; i++) {
      final group = dashboard.groups[i];
      if (group.accounts.isEmpty) continue;

      final rows = <SpreadsheetRow>[];

      for (var j = 0; j < group.accounts.length; j++) {
        final account = group.accounts[j];
        final txMonths = monthlyByAccount[account.accountId];

        final months = List<SpreadsheetMonthValue>.generate(12, (monthIndex) {
          final txValue =
              txMonths?[monthIndex] ?? const SpreadsheetMonthValue.zero();
          final dashboardValue = account.months[monthIndex + 1]?.total ?? 0;

          if (txValue.total == 0 && dashboardValue > 0) {
            return SpreadsheetMonthValue(completed: dashboardValue, pending: 0);
          }

          return txValue;
        });

        rows.add(
          SpreadsheetRow(
            id: account.accountId,
            label: account.accountName,
            sectionId: 'section-$i',
            isIncome: account.isIncome,
            sortOrder: j,
            months: months,
          ),
        );
      }

      rows.sort((a, b) {
        final bySort = a.sortOrder.compareTo(b.sortOrder);
        if (bySort != 0) return bySort;
        return a.label.toLowerCase().compareTo(b.label.toLowerCase());
      });

      sections.add(
        SpreadsheetSection(
          id: 'section-$i',
          label: group.groupName,
          isIncome: rows.any((r) => r.isIncome),
          sortOrder: i,
          rows: rows,
        ),
      );
    }

    sections.sort((a, b) {
      if (a.isIncome != b.isIncome) return a.isIncome ? -1 : 1;
      final bySort = a.sortOrder.compareTo(b.sortOrder);
      if (bySort != 0) return bySort;
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });

    return SpreadsheetData(year: year, sections: sections);
  }

  List<SpreadsheetRow> get rows =>
      sections.expand((s) => s.rows).toList(growable: false);

  List<double> sectionTotals(String sectionId, SpreadsheetProjectionMode mode) {
    final rows = sections.firstWhere((s) => s.id == sectionId).rows;
    return List<double>.generate(12, (month) {
      var total = 0.0;
      for (final row in rows) {
        total += row.monthValue(month, mode);
      }
      return total;
    });
  }

  double sectionGrandTotal(String sectionId, SpreadsheetProjectionMode mode) =>
      sectionTotals(sectionId, mode).fold(0.0, (sum, value) => sum + value);

  List<double> netCashFlowMonths(SpreadsheetProjectionMode mode) {
    return List<double>.generate(12, (month) {
      var income = 0.0;
      var expense = 0.0;
      for (final row in rows) {
        if (row.isIncome) {
          income += row.monthValue(month, mode);
        } else {
          expense += row.monthValue(month, mode);
        }
      }
      return income - expense;
    });
  }

  double netCashFlowTotal(SpreadsheetProjectionMode mode) =>
      netCashFlowMonths(mode).fold(0.0, (sum, value) => sum + value);
}

class SpreadsheetSection {
  final String id;
  final String label;
  final bool isIncome;
  final int sortOrder;
  final List<SpreadsheetRow> rows;

  const SpreadsheetSection({
    required this.id,
    required this.label,
    required this.isIncome,
    required this.sortOrder,
    required this.rows,
  });
}

class SpreadsheetRow {
  final String id;
  final String label;
  final String sectionId;
  final bool isIncome;
  final int sortOrder;
  final List<SpreadsheetMonthValue> months;

  const SpreadsheetRow({
    required this.id,
    required this.label,
    required this.sectionId,
    required this.isIncome,
    required this.sortOrder,
    required this.months,
  });

  double monthValue(int monthIndex, SpreadsheetProjectionMode mode) {
    return months[monthIndex].valueFor(mode: mode, isIncome: isIncome);
  }

  bool monthUsesEstimate(int monthIndex, SpreadsheetProjectionMode mode) {
    return months[monthIndex].usesEstimate(mode: mode, isIncome: isIncome);
  }

  bool totalUsesEstimate(SpreadsheetProjectionMode mode) {
    for (var i = 0; i < months.length; i++) {
      if (monthUsesEstimate(i, mode)) return true;
    }
    return false;
  }

  double totalFor(SpreadsheetProjectionMode mode) {
    var total = 0.0;
    for (var i = 0; i < months.length; i++) {
      total += monthValue(i, mode);
    }
    return total;
  }
}

class SpreadsheetMonthValue {
  final double completed;
  final double pending;

  const SpreadsheetMonthValue({required this.completed, required this.pending});

  const SpreadsheetMonthValue.zero() : completed = 0, pending = 0;

  double get total => completed + pending;

  SpreadsheetMonthValue copyWith({double? completed, double? pending}) {
    return SpreadsheetMonthValue(
      completed: completed ?? this.completed,
      pending: pending ?? this.pending,
    );
  }

  double valueFor({
    required SpreadsheetProjectionMode mode,
    required bool isIncome,
  }) {
    if (!isIncome) return total;
    if (mode == SpreadsheetProjectionMode.prevision) return total;
    return completed;
  }

  bool usesEstimate({
    required SpreadsheetProjectionMode mode,
    required bool isIncome,
  }) {
    return isIncome &&
        mode == SpreadsheetProjectionMode.prevision &&
        pending > 0.0001;
  }
}
