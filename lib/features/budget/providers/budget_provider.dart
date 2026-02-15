import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/services/api_client.dart';

class AccountSpending {
  final String accountId;
  final String accountName;
  final String group;
  final String? groupId;
  final bool isFixed;
  final double budget;
  final double spent;
  final double percentage;

  const AccountSpending({
    required this.accountId,
    required this.accountName,
    required this.group,
    required this.groupId,
    required this.isFixed,
    required this.budget,
    required this.spent,
    required this.percentage,
  });

  factory AccountSpending.fromJson(Map<String, dynamic> json) =>
      AccountSpending(
        accountId: json['accountId'] as String,
        accountName: json['accountName'] as String,
        group: json['group'] as String,
        groupId: json['groupId'] as String?,
        isFixed: json['isFixed'] as bool,
        budget: (json['budget'] as num).toDouble(),
        spent: (json['spent'] as num).toDouble(),
        percentage: (json['percentage'] as num).toDouble(),
      );
}

class BudgetPlanCopySource {
  final int year;
  final int month;

  const BudgetPlanCopySource({required this.year, required this.month});

  factory BudgetPlanCopySource.fromJson(Map<String, dynamic> json) =>
      BudgetPlanCopySource(
        year: json['year'] as int,
        month: json['month'] as int,
      );
}

class BudgetPlanGroupCategory {
  final String accountId;
  final String accountName;
  final bool isFixed;
  final double budget;
  final double spent;
  final double percentage;

  const BudgetPlanGroupCategory({
    required this.accountId,
    required this.accountName,
    required this.isFixed,
    required this.budget,
    required this.spent,
    required this.percentage,
  });

  factory BudgetPlanGroupCategory.fromJson(Map<String, dynamic> json) =>
      BudgetPlanGroupCategory(
        accountId: json['accountId'] as String,
        accountName: json['accountName'] as String,
        isFixed: json['isFixed'] as bool,
        budget: (json['budget'] as num).toDouble(),
        spent: (json['spent'] as num).toDouble(),
        percentage: (json['percentage'] as num).toDouble(),
      );
}

class BudgetPlanGroup {
  final String groupId;
  final String groupName;
  final int sortOrder;
  final bool isFixedGroup;
  final List<BudgetPlanGroupCategory> categories;
  final double spentActual;
  final double plannedPercent;
  final double plannedAmount;
  final String inputMode;
  final int priority;

  const BudgetPlanGroup({
    required this.groupId,
    required this.groupName,
    required this.sortOrder,
    required this.isFixedGroup,
    required this.categories,
    required this.spentActual,
    required this.plannedPercent,
    required this.plannedAmount,
    required this.inputMode,
    required this.priority,
  });

  factory BudgetPlanGroup.fromJson(Map<String, dynamic> json) =>
      BudgetPlanGroup(
        groupId: json['groupId'] as String,
        groupName: json['groupName'] as String,
        sortOrder: json['sortOrder'] as int,
        isFixedGroup: json['isFixedGroup'] as bool,
        categories: (json['categories'] as List)
            .map(
              (c) =>
                  BudgetPlanGroupCategory.fromJson(c as Map<String, dynamic>),
            )
            .toList(),
        spentActual: (json['spentActual'] as num).toDouble(),
        plannedPercent: (json['plannedPercent'] as num).toDouble(),
        plannedAmount: (json['plannedAmount'] as num).toDouble(),
        inputMode: (json['inputMode'] as String?) ?? 'percent',
        priority: (json['priority'] as num?)?.toInt() ?? 0,
      );
}

class BudgetPlan {
  final String id;
  final double forecastDisposableIncome;
  final double totalAllocatedPercent;
  final double totalAllocatedAmount;
  final double remainingPercent;
  final double remainingAmount;
  final BudgetPlanCopySource? copiedFrom;
  final List<BudgetPlanGroup> groups;

  const BudgetPlan({
    required this.id,
    required this.forecastDisposableIncome,
    required this.totalAllocatedPercent,
    required this.totalAllocatedAmount,
    required this.remainingPercent,
    required this.remainingAmount,
    required this.copiedFrom,
    required this.groups,
  });

  factory BudgetPlan.fromJson(Map<String, dynamic> json) => BudgetPlan(
    id: json['id'] as String,
    forecastDisposableIncome: (json['forecastDisposableIncome'] as num)
        .toDouble(),
    totalAllocatedPercent: (json['totalAllocatedPercent'] as num).toDouble(),
    totalAllocatedAmount: (json['totalAllocatedAmount'] as num).toDouble(),
    remainingPercent: (json['remainingPercent'] as num).toDouble(),
    remainingAmount: (json['remainingAmount'] as num).toDouble(),
    copiedFrom: json['copiedFrom'] == null
        ? null
        : BudgetPlanCopySource.fromJson(
            json['copiedFrom'] as Map<String, dynamic>,
          ),
    groups: (json['groups'] as List)
        .map((g) => BudgetPlanGroup.fromJson(g as Map<String, dynamic>))
        .toList(),
  );
}

class BudgetStats {
  final double averageIncome;
  final double fixedExpensesTotal;
  final double disposableIncome;
  final int selectedYear;
  final int selectedMonth;
  final List<AccountSpending> currentMonthSpending;
  final BudgetPlan budgetPlan;

  const BudgetStats({
    required this.averageIncome,
    required this.fixedExpensesTotal,
    required this.disposableIncome,
    required this.selectedYear,
    required this.selectedMonth,
    required this.currentMonthSpending,
    required this.budgetPlan,
  });

  factory BudgetStats.fromJson(Map<String, dynamic> json) => BudgetStats(
    averageIncome: (json['averageIncome'] as num).toDouble(),
    fixedExpensesTotal: (json['fixedExpensesTotal'] as num).toDouble(),
    disposableIncome: (json['disposableIncome'] as num).toDouble(),
    selectedYear: (json['selectedYear'] as num).toInt(),
    selectedMonth: (json['selectedMonth'] as num).toInt(),
    currentMonthSpending: (json['currentMonthSpending'] as List)
        .map((s) => AccountSpending.fromJson(s as Map<String, dynamic>))
        .toList(),
    budgetPlan: BudgetPlan.fromJson(json['budgetPlan'] as Map<String, dynamic>),
  );
}

class BudgetMonthKey {
  final int year;
  final int month;

  const BudgetMonthKey({required this.year, required this.month});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BudgetMonthKey &&
          runtimeType == other.runtimeType &&
          year == other.year &&
          month == other.month;

  @override
  int get hashCode => Object.hash(year, month);
}

class BudgetPlanGroupUpdate {
  final String groupId;
  final String inputMode;
  final double plannedPercent;
  final double plannedAmount;
  final int priority;

  const BudgetPlanGroupUpdate({
    required this.groupId,
    required this.inputMode,
    required this.plannedPercent,
    required this.plannedAmount,
    required this.priority,
  });

  Map<String, dynamic> toJson() => {
    'groupId': groupId,
    'inputMode': inputMode,
    'plannedPercent': plannedPercent,
    'plannedAmount': plannedAmount,
    'priority': priority,
  };
}

class BudgetPlanApi {
  final ApiClient _client;

  const BudgetPlanApi(this._client);

  Future<BudgetStats> fetchStats({
    required int year,
    required int month,
    bool reusePlan = true,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/budget/stats',
      queryParameters: {'year': year, 'month': month, 'reusePlan': reusePlan},
    );
    return BudgetStats.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> upsertPlan({
    required int year,
    required int month,
    required double forecastDisposableIncome,
    required List<BudgetPlanGroupUpdate> groups,
  }) async {
    await _client.put<Map<String, dynamic>>(
      '/api/budget/plan/$year/$month',
      data: {
        'forecastDisposableIncome': forecastDisposableIncome,
        'groups': groups.map((g) => g.toJson()).toList(),
      },
    );
  }
}

final selectedBudgetMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

final budgetPlanApiProvider = Provider<BudgetPlanApi>((ref) {
  final client = ref.watch(apiClientProvider);
  return BudgetPlanApi(client);
});

final budgetStatsProvider = FutureProvider.family<BudgetStats, BudgetMonthKey>((
  ref,
  key,
) async {
  final api = ref.watch(budgetPlanApiProvider);
  return api.fetchStats(year: key.year, month: key.month, reusePlan: true);
});
