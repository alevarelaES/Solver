import 'package:flutter/material.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/l10n/app_strings.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/dashboard/models/dashboard_data.dart';
import 'package:solver/shared/widgets/glass_container.dart';

class SpendingLimit extends StatelessWidget {
  final DashboardData data;

  const SpendingLimit({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final spent = data.currentMonthExpenses;
    final income = data.currentMonthIncome;
    final ratio = income > 0 ? (spent / income).clamp(0.0, 1.0) : 0.0;

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
                AppStrings.dashboard.monthlySpendingLimit,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              Row(
                children: [
                  // Set limit link
                  GestureDetector(
                    onTap: () {
                      // TODO: open set limit dialog
                    },
                    child: Text(
                      AppStrings.dashboard.setLimit,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    '${(ratio * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: AppSizes.progressBarHeight,
              backgroundColor: isDark
                  ? AppColors.borderDark
                  : AppColors.surfaceHeader,
              valueColor: AlwaysStoppedAnimation(
                ratio > 0.9 ? AppColors.danger : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppFormats.formatFromChfCompact(spent),
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              Text(
                AppFormats.formatFromChfCompact(income),
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
