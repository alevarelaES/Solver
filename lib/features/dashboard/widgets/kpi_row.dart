import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/l10n/app_strings.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/dashboard/models/dashboard_data.dart';
import 'package:solver/shared/widgets/glass_container.dart';

class KpiRow extends StatelessWidget {
  final DashboardData data;

  const KpiRow({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final savings = data.currentMonthIncome - data.currentMonthExpenses;
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < AppBreakpoints.mobile;

    // Compute percentage changes (mock for now — would need previous month data)
    final cards = [
      _KpiCardData(
        label: AppStrings.dashboard.income,
        amount: data.currentMonthIncome,
        color: AppColors.success,
        isUp: true,
        percentChange: 12.2,
      ),
      _KpiCardData(
        label: AppStrings.dashboard.expense,
        amount: data.currentMonthExpenses,
        color: AppColors.danger,
        isUp: false,
        percentChange: 16.2,
      ),
      _KpiCardData(
        label: AppStrings.dashboard.savings,
        amount: savings,
        color: savings >= 0 ? AppColors.success : AppColors.danger,
        isUp: savings >= 0,
        percentChange: 7.5,
      ),
    ];

    if (isNarrow) {
      return Column(
        children: cards.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _KpiCard(data: c),
        )).toList(),
      );
    }

    return Row(
      children: cards.asMap().entries.map((entry) => Expanded(
        child: Padding(
          padding: EdgeInsets.only(
            right: entry.key < cards.length - 1 ? AppSpacing.lg : 0,
          ),
          child: _KpiCard(data: entry.value),
        ),
      )).toList(),
    );
  }
}

class _KpiCardData {
  final String label;
  final double amount;
  final Color color;
  final bool isUp;
  final double percentChange;

  const _KpiCardData({
    required this.label,
    required this.amount,
    required this.color,
    required this.isUp,
    required this.percentChange,
  });
}

class _KpiCard extends StatelessWidget {
  final _KpiCardData data;

  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      padding: AppSpacing.paddingCardCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            data.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppFormats.currency.format(data.amount),
            style: GoogleFonts.robotoMono(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              // Percentage badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      data.isUp ? Icons.north : Icons.south,
                      size: 10,
                      color: data.color,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${data.percentChange.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 10,
                        color: data.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                AppStrings.dashboard.thisMonth,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? AppColors.textDisabledDark : AppColors.textDisabledLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
