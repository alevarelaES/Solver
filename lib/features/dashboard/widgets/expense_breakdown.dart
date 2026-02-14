import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/l10n/app_strings.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/dashboard/models/dashboard_data.dart';
import 'package:solver/shared/widgets/glass_container.dart';

class ExpenseBreakdown extends StatelessWidget {
  final DashboardData data;

  const ExpenseBreakdown({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentMonth = DateTime.now().month;

    // Collect expense accounts with their current month totals
    final entries = <_ExpenseEntry>[];
    for (final group in data.groups) {
      for (final account in group.accounts) {
        if (account.isIncome) continue;
        final cell = account.months[currentMonth];
        if (cell == null || cell.total == 0) continue;
        entries.add(_ExpenseEntry(account.accountName, cell.total));
      }
    }

    if (entries.isEmpty) {
      return GlassContainer(
        padding: AppSpacing.paddingCardCompact,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isDark),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: Text(
                AppStrings.dashboard.noExpenses,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.textDisabledDark
                      : AppColors.textDisabledLight,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final colors = [
      AppColors.primary,
      AppColors.primaryDark,
      AppColors.primaryDarker,
      const Color(0xFFD1D5DB),
      AppColors.warning,
      AppColors.info,
    ];

    return GlassContainer(
      padding: AppSpacing.paddingCardCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(isDark),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              // Donut chart
              SizedBox(
                width: AppSizes.donutSize,
                height: AppSizes.donutSize,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 0,
                    centerSpaceRadius: AppSizes.donutCutout,
                    sections: List.generate(entries.length, (i) {
                      return PieChartSectionData(
                        value: entries[i].amount,
                        color: colors[i % colors.length],
                        radius: AppSizes.donutRingWidth,
                        showTitle: false,
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xl),
              // Legend
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(entries.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: AppSizes.dotSizeSm,
                                  height: AppSizes.dotSizeSm,
                                  decoration: BoxDecoration(
                                    color: colors[i % colors.length],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    entries[i].name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            AppFormats.currencyCompact.format(
                              entries[i].amount,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Text(
      AppStrings.dashboard.expenseBreakdown,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 13,
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      ),
    );
  }
}

class _ExpenseEntry {
  final String name;
  final double amount;
  const _ExpenseEntry(this.name, this.amount);
}
