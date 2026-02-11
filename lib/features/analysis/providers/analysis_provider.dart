import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/services/api_client.dart';

class GroupExpense {
  final String group;
  final double total;
  final double percentage;

  const GroupExpense({required this.group, required this.total, required this.percentage});

  factory GroupExpense.fromJson(Map<String, dynamic> json) => GroupExpense(
        group: json['group'] as String,
        total: (json['total'] as num).toDouble(),
        percentage: (json['percentage'] as num).toDouble(),
      );
}

class MonthData {
  final int month;
  final double income;
  final double expenses;
  final double savings;

  const MonthData({
    required this.month,
    required this.income,
    required this.expenses,
    required this.savings,
  });

  factory MonthData.fromJson(Map<String, dynamic> json) => MonthData(
        month: json['month'] as int,
        income: (json['income'] as num).toDouble(),
        expenses: (json['expenses'] as num).toDouble(),
        savings: (json['savings'] as num).toDouble(),
      );
}

class TopAccount {
  final String accountName;
  final double total;
  final double budget;

  const TopAccount({required this.accountName, required this.total, required this.budget});

  factory TopAccount.fromJson(Map<String, dynamic> json) => TopAccount(
        accountName: json['accountName'] as String,
        total: (json['total'] as num).toDouble(),
        budget: (json['budget'] as num).toDouble(),
      );
}

class AnalysisData {
  final List<GroupExpense> byGroup;
  final List<MonthData> byMonth;
  final List<TopAccount> topExpenseAccounts;
  final double savingsRate;
  final double totalIncome;
  final double totalExpenses;

  const AnalysisData({
    required this.byGroup,
    required this.byMonth,
    required this.topExpenseAccounts,
    required this.savingsRate,
    required this.totalIncome,
    required this.totalExpenses,
  });

  factory AnalysisData.fromJson(Map<String, dynamic> json) => AnalysisData(
        byGroup: (json['byGroup'] as List)
            .map((g) => GroupExpense.fromJson(g as Map<String, dynamic>))
            .toList(),
        byMonth: (json['byMonth'] as List)
            .map((m) => MonthData.fromJson(m as Map<String, dynamic>))
            .toList(),
        topExpenseAccounts: (json['topExpenseAccounts'] as List)
            .map((a) => TopAccount.fromJson(a as Map<String, dynamic>))
            .toList(),
        savingsRate: (json['savingsRate'] as num).toDouble(),
        totalIncome: (json['totalIncome'] as num).toDouble(),
        totalExpenses: (json['totalExpenses'] as num).toDouble(),
      );
}

final selectedAnalysisYearProvider = StateProvider<int>((ref) => DateTime.now().year);

final analysisDataProvider = FutureProvider.family<AnalysisData, int>((ref, year) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get<Map<String, dynamic>>(
    '/api/analysis',
    queryParameters: {'year': year},
  );
  return AnalysisData.fromJson(response.data as Map<String, dynamic>);
});
