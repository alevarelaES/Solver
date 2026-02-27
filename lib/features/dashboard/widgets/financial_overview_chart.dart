import 'dart:math' as math;

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

enum _OverviewRange { month, quarter, year }

class FinancialOverviewChart extends ConsumerStatefulWidget {
  final DashboardData data;
  final int year;
  final double? chartHeight;

  const FinancialOverviewChart({
    super.key,
    required this.data,
    required this.year,
    this.chartHeight,
  });

  @override
  ConsumerState<FinancialOverviewChart> createState() =>
      _FinancialOverviewChartState();
}

class _FinancialOverviewChartState
    extends ConsumerState<FinancialOverviewChart> {
  _OverviewRange _range = _OverviewRange.year;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentMonth = DateTime.now().month;
    final currentYear = DateTime.now().year;
    final projectionAsync = ref.watch(
      yearlyExpenseProjectionProvider(widget.year),
    );

    final incomes = List<double>.filled(12, 0);
    final expenses = List<double>.filled(12, 0);

    for (final group in widget.data.groups) {
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

    if (widget.year == currentYear) {
      for (int m = currentMonth + 1; m <= 12; m++) {
        incomes[m - 1] = 0;
      }

      final projection = projectionAsync.valueOrNull;
      if (projection != null) {
        for (int m = currentMonth + 1; m <= 12; m++) {
          final i = m - 1;
          if (i >= projection.totalByMonth.length) continue;
          expenses[i] = projection.totalByMonth[i];
        }
      }
    }

    // Convert CHF amounts to the active currency before charting.
    final convertedIncomes = incomes.map(AppFormats.fromChf).toList();
    final convertedExpenses = expenses.map(AppFormats.fromChf).toList();

    final buckets = _buildBuckets(
      incomes: convertedIncomes,
      expenses: convertedExpenses,
      range: _range,
      year: widget.year,
      currentYear: currentYear,
      currentMonth: currentMonth,
    );

    final maxY = _computeMaxY(buckets);

    return GlassContainer(
      padding: AppSpacing.paddingCardCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppStrings.dashboard.financialOverview,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
              _RangeToggle(
                value: _range,
                onChanged: (value) => setState(() => _range = value),
              ),
              const SizedBox(width: AppSpacing.md),
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
          SizedBox(
            height: widget.chartHeight ?? AppSizes.chartHeight,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots.map((spot) {
                      final isIncome = spot.barIndex == 0;
                      return LineTooltipItem(
                        '${isIncome ? AppStrings.dashboard.income : AppStrings.dashboard.expense}\n'
                        '${AppFormats.currencyCompact.format(spot.y)}',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      buckets.length,
                      (i) => FlSpot(i.toDouble(), buckets[i].income),
                    ),
                    isCurved: true,
                    curveSmoothness: 0.3,
                    preventCurveOverShooting: true,
                    color: AppColors.primary,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      checkToShowDot: (spot, _) {
                        final i = spot.x.toInt();
                        return i < buckets.length && buckets[i].isCurrent;
                      },
                      getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                        radius: 4,
                        color: AppColors.primary,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primary.withValues(alpha: 0.18),
                          AppColors.primary.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: List.generate(
                      buckets.length,
                      (i) => FlSpot(i.toDouble(), buckets[i].expense),
                    ),
                    isCurved: true,
                    curveSmoothness: 0.3,
                    preventCurveOverShooting: true,
                    color: AppColors.danger,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      checkToShowDot: (spot, _) {
                        final i = spot.x.toInt();
                        return i < buckets.length && buckets[i].isCurrent;
                      },
                      getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                        radius: 4,
                        color: AppColors.danger,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.danger.withValues(alpha: 0.1),
                          AppColors.danger.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
                minX: 0,
                maxX: (buckets.length - 1).toDouble(),
                minY: 0,
                maxY: maxY,
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
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= buckets.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Text(
                            buckets[index].label,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? AppColors.textDisabledDark
                                  : AppColors.textDisabledLight,
                            ),
                          ),
                        );
                      },
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeToggle extends StatelessWidget {
  final _OverviewRange value;
  final ValueChanged<_OverviewRange> onChanged;

  const _RangeToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.borderDark
              : AppColors.borderLight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RangeToggleItem(
            label: AppStrings.dashboard.rangeMonth,
            selected: value == _OverviewRange.month,
            onTap: () => onChanged(_OverviewRange.month),
          ),
          _RangeToggleItem(
            label: AppStrings.dashboard.rangeQuarter,
            selected: value == _OverviewRange.quarter,
            onTap: () => onChanged(_OverviewRange.quarter),
          ),
          _RangeToggleItem(
            label: AppStrings.dashboard.rangeYear,
            selected: value == _OverviewRange.year,
            onTap: () => onChanged(_OverviewRange.year),
          ),
        ],
      ),
    );
  }
}

class _RangeToggleItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RangeToggleItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.15) : null,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _OverviewBucket {
  final String label;
  final double income;
  final double expense;
  final bool isCurrent;

  const _OverviewBucket({
    required this.label,
    required this.income,
    required this.expense,
    required this.isCurrent,
  });
}

List<_OverviewBucket> _buildBuckets({
  required List<double> incomes,
  required List<double> expenses,
  required _OverviewRange range,
  required int year,
  required int currentYear,
  required int currentMonth,
}) {
  final labels = AppStrings.common.monthsShort;
  final nowMonthIndex = currentMonth - 1;
  final isCurrentYear = year == currentYear;

  switch (range) {
    case _OverviewRange.year:
      return List.generate(12, (i) {
        return _OverviewBucket(
          label: labels[i],
          income: incomes[i],
          expense: expenses[i],
          isCurrent: isCurrentYear && i == nowMonthIndex,
        );
      });

    case _OverviewRange.quarter:
      return List.generate(4, (q) {
        final start = q * 3;
        final end = start + 2;
        final income = incomes
            .sublist(start, end + 1)
            .fold(0.0, (a, b) => a + b);
        final expense = expenses
            .sublist(start, end + 1)
            .fold(0.0, (a, b) => a + b);
        final isCurrent = isCurrentYear && (nowMonthIndex ~/ 3) == q;
        return _OverviewBucket(
          label: 'T${q + 1}',
          income: income,
          expense: expense,
          isCurrent: isCurrent,
        );
      });

    case _OverviewRange.month:
      final end = isCurrentYear ? nowMonthIndex : 11;
      final start = math.max(0, end - 5);
      return List.generate(end - start + 1, (idx) {
        final i = start + idx;
        return _OverviewBucket(
          label: labels[i],
          income: incomes[i],
          expense: expenses[i],
          isCurrent: isCurrentYear && i == nowMonthIndex,
        );
      });
  }
}

double _computeMaxY(List<_OverviewBucket> buckets) {
  if (buckets.isEmpty) return 1;
  var maxValue = 1.0;
  for (final bucket in buckets) {
    if (bucket.income > maxValue) maxValue = bucket.income;
    if (bucket.expense > maxValue) maxValue = bucket.expense;
  }
  return maxValue * 1.15;
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
