class MonthCell {
  final double total;
  final int pendingCount;
  final int completedCount;

  const MonthCell({
    required this.total,
    required this.pendingCount,
    required this.completedCount,
  });

  factory MonthCell.fromJson(Map<String, dynamic> json) => MonthCell(
        total: (json['total'] as num).toDouble(),
        pendingCount: json['pendingCount'] as int,
        completedCount: json['completedCount'] as int,
      );

  bool get hasPending => pendingCount > 0;
  bool get isEmpty => total == 0 && pendingCount == 0 && completedCount == 0;
}

class AccountMonthlyData {
  final String accountId;
  final String accountName;
  final String accountType; // 'income' or 'expense'
  final Map<int, MonthCell> months;

  const AccountMonthlyData({
    required this.accountId,
    required this.accountName,
    required this.accountType,
    required this.months,
  });

  bool get isIncome => accountType == 'income';

  factory AccountMonthlyData.fromJson(Map<String, dynamic> json) {
    final rawMonths = json['months'] as Map<String, dynamic>;
    final months = rawMonths.map(
      (key, value) => MapEntry(
        int.parse(key),
        MonthCell.fromJson(value as Map<String, dynamic>),
      ),
    );
    return AccountMonthlyData(
      accountId: json['accountId'] as String,
      accountName: json['accountName'] as String,
      accountType: json['accountType'] as String,
      months: months,
    );
  }
}

class GroupData {
  final String groupName;
  final List<AccountMonthlyData> accounts;

  const GroupData({required this.groupName, required this.accounts});

  factory GroupData.fromJson(Map<String, dynamic> json) => GroupData(
        groupName: json['groupName'] as String,
        accounts: (json['accounts'] as List)
            .map((a) => AccountMonthlyData.fromJson(a as Map<String, dynamic>))
            .toList(),
      );
}

class DashboardData {
  final double currentBalance;
  final double currentMonthIncome;
  final double currentMonthExpenses;
  final double projectedEndOfMonth;
  final double balanceBeforeYear;
  final List<GroupData> groups;

  const DashboardData({
    required this.currentBalance,
    required this.currentMonthIncome,
    required this.currentMonthExpenses,
    required this.projectedEndOfMonth,
    required this.balanceBeforeYear,
    required this.groups,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) => DashboardData(
        currentBalance: (json['currentBalance'] as num).toDouble(),
        currentMonthIncome: (json['currentMonthIncome'] as num).toDouble(),
        currentMonthExpenses: (json['currentMonthExpenses'] as num).toDouble(),
        projectedEndOfMonth: (json['projectedEndOfMonth'] as num).toDouble(),
        balanceBeforeYear: (json['balanceBeforeYear'] as num).toDouble(),
        groups: (json['groups'] as List)
            .map((g) => GroupData.fromJson(g as Map<String, dynamic>))
            .toList(),
      );

  /// Net balance at end of each month (for footer).
  /// Starts from [balanceBeforeYear] and accumulates month by month.
  List<double> computeMonthlyBalances() {
    final balances = List<double>.filled(12, 0);
    var running = balanceBeforeYear;

    for (int m = 1; m <= 12; m++) {
      for (final group in groups) {
        for (final account in group.accounts) {
          final cell = account.months[m];
          if (cell == null) continue;
          running += account.isIncome ? cell.total : -cell.total;
        }
      }
      balances[m - 1] = running;
    }
    return balances;
  }
}
