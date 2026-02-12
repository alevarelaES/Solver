import 'package:flutter_test/flutter_test.dart';
import 'package:solver/features/dashboard/models/dashboard_data.dart';

void main() {
  group('MonthCell', () {
    test('hasPending returns true when pendingCount > 0', () {
      const cell = MonthCell(total: 100, pendingCount: 2, completedCount: 1);
      expect(cell.hasPending, isTrue);
    });

    test('hasPending returns false when pendingCount is 0', () {
      const cell = MonthCell(total: 100, pendingCount: 0, completedCount: 3);
      expect(cell.hasPending, isFalse);
    });

    test('isEmpty returns true when all values are zero', () {
      const cell = MonthCell(total: 0, pendingCount: 0, completedCount: 0);
      expect(cell.isEmpty, isTrue);
    });

    test('isEmpty returns false when total is non-zero', () {
      const cell = MonthCell(total: 50, pendingCount: 0, completedCount: 1);
      expect(cell.isEmpty, isFalse);
    });
  });

  group('AccountMonthlyData', () {
    test('isIncome returns true for income type', () {
      const account = AccountMonthlyData(
        accountId: 'abc',
        accountName: 'Salary',
        accountType: 'income',
        months: {},
      );
      expect(account.isIncome, isTrue);
    });

    test('isIncome returns false for expense type', () {
      const account = AccountMonthlyData(
        accountId: 'def',
        accountName: 'Rent',
        accountType: 'expense',
        months: {},
      );
      expect(account.isIncome, isFalse);
    });
  });

  group('DashboardData.computeMonthlyBalances', () {
    test('accumulates balance correctly across months', () {
      final data = DashboardData(
        currentBalance: 0,
        currentMonthIncome: 0,
        currentMonthExpenses: 0,
        projectedEndOfMonth: 0,
        balanceBeforeYear: 1000, // Start with 1000
        groups: [
          GroupData(groupName: 'Revenus', accounts: [
            AccountMonthlyData(
              accountId: '1',
              accountName: 'Salary',
              accountType: 'income',
              months: {
                1: const MonthCell(total: 5000, pendingCount: 0, completedCount: 1),
                2: const MonthCell(total: 5000, pendingCount: 0, completedCount: 1),
                3: const MonthCell(total: 5000, pendingCount: 0, completedCount: 1),
              },
            ),
          ]),
          GroupData(groupName: 'Charges', accounts: [
            AccountMonthlyData(
              accountId: '2',
              accountName: 'Rent',
              accountType: 'expense',
              months: {
                1: const MonthCell(total: 1500, pendingCount: 0, completedCount: 1),
                2: const MonthCell(total: 1500, pendingCount: 0, completedCount: 1),
                3: const MonthCell(total: 1500, pendingCount: 0, completedCount: 1),
              },
            ),
          ]),
        ],
      );

      final balances = data.computeMonthlyBalances();

      // Month 1: 1000 + 5000 - 1500 = 4500
      expect(balances[0], 4500);
      // Month 2: 4500 + 5000 - 1500 = 8000
      expect(balances[1], 8000);
      // Month 3: 8000 + 5000 - 1500 = 11500
      expect(balances[2], 11500);
      // Months 4-12: no transactions, balance stays at 11500
      for (int i = 3; i < 12; i++) {
        expect(balances[i], 11500);
      }
    });

    test('returns zeros for empty groups with zero balanceBeforeYear', () {
      const data = DashboardData(
        currentBalance: 0,
        currentMonthIncome: 0,
        currentMonthExpenses: 0,
        projectedEndOfMonth: 0,
        balanceBeforeYear: 0,
        groups: [],
      );

      final balances = data.computeMonthlyBalances();

      expect(balances.length, 12);
      expect(balances.every((b) => b == 0), isTrue);
    });
  });
}
