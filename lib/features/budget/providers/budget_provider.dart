import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/services/api_client.dart';

class AccountSpending {
  final String accountId;
  final String accountName;
  final String group;
  final bool isFixed;
  final double budget;
  final double spent;
  final double percentage;

  const AccountSpending({
    required this.accountId,
    required this.accountName,
    required this.group,
    required this.isFixed,
    required this.budget,
    required this.spent,
    required this.percentage,
  });

  factory AccountSpending.fromJson(Map<String, dynamic> json) => AccountSpending(
        accountId: json['accountId'] as String,
        accountName: json['accountName'] as String,
        group: json['group'] as String,
        isFixed: json['isFixed'] as bool,
        budget: (json['budget'] as num).toDouble(),
        spent: (json['spent'] as num).toDouble(),
        percentage: (json['percentage'] as num).toDouble(),
      );
}

class BudgetStats {
  final double averageIncome;
  final double fixedExpensesTotal;
  final double disposableIncome;
  final List<AccountSpending> currentMonthSpending;

  const BudgetStats({
    required this.averageIncome,
    required this.fixedExpensesTotal,
    required this.disposableIncome,
    required this.currentMonthSpending,
  });

  factory BudgetStats.fromJson(Map<String, dynamic> json) => BudgetStats(
        averageIncome: (json['averageIncome'] as num).toDouble(),
        fixedExpensesTotal: (json['fixedExpensesTotal'] as num).toDouble(),
        disposableIncome: (json['disposableIncome'] as num).toDouble(),
        currentMonthSpending: (json['currentMonthSpending'] as List)
            .map((s) => AccountSpending.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

final budgetStatsProvider = FutureProvider<BudgetStats>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get<Map<String, dynamic>>('/api/budget/stats');
  return BudgetStats.fromJson(response.data as Map<String, dynamic>);
});
