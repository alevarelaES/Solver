import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/l10n/app_strings.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/dashboard/models/dashboard_data.dart';
import 'package:solver/features/schedule/providers/schedule_provider.dart';
import 'package:solver/shared/widgets/glass_container.dart';

class FinancialOverviewChart extends ConsumerWidget {
  final DashboardData data;
  final int year;

  const FinancialOverviewChart({
    super.key,
    required this.data,
    required this.year,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentMonth = DateTime.now().month;
    final currentYear = DateTime.now().year;
    final projectionAsync = ref.watch(yearlyExpenseProjectionProvider(year));

    final incomes = List<double>.filled(12, 0);
    final expenses = List<double>.filled(12, 0);

    for (final group in data.groups) {
      for (final account in group.accounts) {
        for (int m = 1; m <= 12; m++) {
          final cell = account.months[m];
          if (cell == null) continue;
          if (account.isIncome) {
            incomes[m - 1] += cell.total;
          } else {
            expenses[m - 1] += cell.total;
          }
        }
      }
    }

    if (year == currentYear) {
      for (int m = currentMonth + 1; m <= 12; m++) {
        incomes[m - 1] = 0;
      }

      projectionAsync.whenData((projection) {
        for (int m = currentMonth + 1; m <= 12; m++) {
          final i = m - 1;
          if (i >= projection.totalByMonth.length) continue;
          // Replace with backend yearly projection to avoid partial/duplicate sums.
          expenses[i] = projection.totalByMonth[i];
        }
      });
    }

    final maxY = _computeMaxY(incomes, expenses);

    return GlassContainer(
      padding: AppSpacing.paddingCardCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.dashboard.financialOverview,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              Row(
                children: [
                  _LegendDot(
                    color: AppColors.primary,
                    label: AppStrings.dashboard.income,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _LegendDot(
                    color: AppColors.danger,
                    label: AppStrings.dashboard.expense,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: SizedBox(
              height: AppSizes.chartHeight,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final label = rodIndex == 0
                            ? AppStrings.dashboard.income
                            : AppStrings.dashboard.expense;
                        return BarTooltipItem(
                          '$label\n${AppFormats.currencyCompact.format(rod.toY)}',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) => Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Text(
                            AppStrings.common.monthsShort[value.toInt()],
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? AppColors.textDisabledDark
                                  : AppColors.textDisabledLight,
                            ),
                          ),
                        ),
                        reservedSize: 28,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (value, meta) => Text(
                          '${(value / 1000).toStringAsFixed(0)}K',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? AppColors.textDisabledDark
                                : AppColors.textDisabledLight,
                          ),
                        ),
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight,
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(12, (i) {
                    final isHighlighted =
                        year == currentYear && (i + 1) == currentMonth;
                    final grayIncome = isDark
                        ? const Color(0xFF4B5563)
                        : const Color(0xFFE5E7EB);
                    final grayExpense = isDark
                        ? const Color(0xFF7F1D1D)
                        : const Color(0xFFFEE2E2);

                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: incomes[i],
                          color: isHighlighted ? AppColors.primary : grayIncome,
                          width: AppSizes.barWidth,
                          borderRadius: BorderRadius.circular(
                            AppSizes.barRadius,
                          ),
                        ),
                        BarChartRodData(
                          toY: expenses[i],
                          color: isHighlighted ? AppColors.danger : grayExpense,
                          width: AppSizes.barWidth,
                          borderRadius: BorderRadius.circular(
                            AppSizes.barRadius,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _computeMaxY(List<double> a, List<double> b) {
    double max = 1;
    for (int i = 0; i < 12; i++) {
      if (a[i] > max) max = a[i];
      if (b[i] > max) max = b[i];
    }
    return max * 1.15;
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: AppSizes.dotSize,
          height: AppSizes.dotSize,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }
}
