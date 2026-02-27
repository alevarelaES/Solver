import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/l10n/app_strings.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/budget/providers/goals_provider.dart';
import 'package:solver/features/dashboard/models/dashboard_data.dart';
import 'package:solver/features/dashboard/widgets/dashboard_kpi_item.dart';

class KpiRow extends ConsumerWidget {
  final DashboardData data;

  const KpiRow({super.key, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < AppBreakpoints.mobile;

    // Total savings from active objectives
    final goalsAsync = ref.watch(goalsProvider);
    final totalSavings = goalsAsync.whenOrNull(
          data: (goals) => goals
              .where((g) => !g.isArchived && g.goalType == 'savings')
              .fold<double>(0, (sum, g) => sum + g.currentAmount),
        ) ??
        0.0;

    // Dynamic % change vs previous month
    final currentMonth = DateTime.now().month;
    final prevMonth = currentMonth == 1 ? 12 : currentMonth - 1;
    final prevIncome = data.incomeForMonth(prevMonth);
    final prevExpenses = data.expensesForMonth(prevMonth);

    double pctChange(double current, double previous) {
      if (previous == 0) return 0.0;
      return ((current - previous) / previous.abs()) * 100;
    }

    final incomePct = pctChange(data.currentMonthIncome, prevIncome);
    final expensePct = pctChange(data.currentMonthExpenses, prevExpenses);

    // Sparkline data (last 6 months up to current month)
    List<double> getSparklineData(bool isIncome) {
      final List<double> result = [];
      for (int i = 5; i >= 0; i--) {
        int m = currentMonth - i;
        if (m <= 0) m += 12; // wrap around for previous year if needed, though data only has 1-12. If data is current year only, previous year is just 0 unless populated.
        result.add(isIncome ? data.incomeForMonth(m) : data.expensesForMonth(m));
      }
      return result;
    }

    // Savings sparkline stub: incremental
    final savingsSparkline = [
      totalSavings * 0.5,
      totalSavings * 0.6,
      totalSavings * 0.7,
      totalSavings * 0.85,
      totalSavings * 0.95,
      totalSavings,
    ];

    final cards = [
      DashboardKpiItem(
        label: AppStrings.dashboard.income,
        amount: data.currentMonthIncome,
        color: AppColors.success,
        percentChange: incomePct,
        sparklineData: getSparklineData(true),
        icon: Icons.trending_up_rounded,
      ),
      DashboardKpiItem(
        label: AppStrings.dashboard.expense,
        amount: data.currentMonthExpenses,
        color: AppColors.danger,
        percentChange: expensePct,
        sparklineData: getSparklineData(false),
        icon: Icons.trending_down_rounded,
      ),
      DashboardKpiItem(
        label: AppStrings.dashboard.savings,
        amount: totalSavings,
        color: AppColors.primary,
        percentChange: null, // No percent change for savings in legacy
        sparklineData: savingsSparkline, // Static stub data mimicking progression
        icon: Icons.savings_outlined,
      ),
    ];

    if (isNarrow) {
      return Column(
        children: cards.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: c,
        )).toList(),
      );
    }

    return Row(
      children: cards.asMap().entries.map((entry) => Expanded(
        child: Padding(
          padding: EdgeInsets.only(
            right: entry.key < cards.length - 1 ? AppSpacing.lg : 0,
          ),
          child: entry.value,
        ),
      )).toList(),
    );
  }
}
