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

    final groups = <_ExpenseGroup>[];
    for (final group in data.groups) {
      final categories = <_ExpenseCategory>[];
      var groupTotal = 0.0;
      for (final account in group.accounts) {
        if (account.isIncome) continue;
        final cell = account.months[currentMonth];
        if (cell == null || cell.total == 0) continue;
        categories.add(_ExpenseCategory(account.accountName, cell.total));
        groupTotal += cell.total;
      }
      if (groupTotal <= 0) continue;
      categories.sort((a, b) => b.amount.compareTo(a.amount));
      groups.add(
        _ExpenseGroup(
          groupName: group.groupName,
          total: groupTotal,
          categories: categories,
        ),
      );
    }

    groups.sort((a, b) => b.total.compareTo(a.total));
    final totalMonth = groups.fold<double>(
      0,
      (sum, group) => sum + group.total,
    );

    return GestureDetector(
      onTap: groups.isEmpty ? null : () => _openDetails(context, groups),
      child: MouseRegion(
        cursor: groups.isEmpty
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: GlassContainer(
          padding: AppSpacing.paddingCardCompact,
          child: groups.isEmpty
              ? _EmptyContent(isDark: isDark, totalMonth: totalMonth)
              : _CardContent(
                  isDark: isDark,
                  groups: groups,
                  totalMonth: totalMonth,
                ),
        ),
      ),
    );
  }

  Future<void> _openDetails(
    BuildContext context,
    List<_ExpenseGroup> groups,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Details depenses du mois',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.55,
                  child: ListView.separated(
                    itemCount: groups.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(
                            color: isDark
                                ? AppColors.borderDark
                                : AppColors.borderLight,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    group.groupName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? AppColors.textPrimaryDark
                                          : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                ),
                                Text(
                                  AppFormats.formatFromChfCompact(group.total),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.textPrimaryLight,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            ...group.categories.map(
                              (category) => Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        category.name,
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
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(
                                      AppFormats.formatFromChfCompact(
                                        category.amount,
                                      ),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? AppColors.textPrimaryDark
                                            : AppColors.textPrimaryLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyContent extends StatelessWidget {
  final bool isDark;
  final double totalMonth;

  const _EmptyContent({required this.isDark, required this.totalMonth});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(isDark: isDark, totalMonth: totalMonth),
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
    );
  }
}

class _CardContent extends StatelessWidget {
  final bool isDark;
  final List<_ExpenseGroup> groups;
  final double totalMonth;

  const _CardContent({
    required this.isDark,
    required this.groups,
    required this.totalMonth,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppColors.primary,
      AppColors.primaryDark,
      AppColors.primaryDarker,
      AppColors.gray300,
      AppColors.warning,
      AppColors.info,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Header(isDark: isDark, totalMonth: totalMonth),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            SizedBox(
              width: AppSizes.donutSize,
              height: AppSizes.donutSize,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 0,
                  centerSpaceRadius: AppSizes.donutCutout,
                  sections: List.generate(groups.length, (i) {
                    return PieChartSectionData(
                      value: groups[i].total,
                      color: colors[i % colors.length],
                      radius: AppSizes.donutRingWidth,
                      showTitle: false,
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xl),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(groups.length, (i) {
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
                                  groups[i].groupName,
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
                          AppFormats.formatFromChfCompact(groups[i].total),
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
    );
  }
}

class _Header extends StatelessWidget {
  final bool isDark;
  final double totalMonth;

  const _Header({required this.isDark, required this.totalMonth});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            AppStrings.dashboard.expenseBreakdown,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
        ),
        Text(
          AppFormats.formatFromChfCompact(totalMonth),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
      ],
    );
  }
}

class _ExpenseGroup {
  final String groupName;
  final double total;
  final List<_ExpenseCategory> categories;

  const _ExpenseGroup({
    required this.groupName,
    required this.total,
    required this.categories,
  });
}

class _ExpenseCategory {
  final String name;
  final double amount;

  const _ExpenseCategory(this.name, this.amount);
}
