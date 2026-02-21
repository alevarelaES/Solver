import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/l10n/app_strings.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/dashboard/models/dashboard_data.dart';

class BalanceCard extends StatelessWidget {
  final DashboardData data;

  const BalanceCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final spent = data.currentMonthExpenses;
    final monthlyLimit = data.currentMonthIncome;
    final usageRatio = monthlyLimit > 0
        ? (spent / monthlyLimit).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.cardGreen(AppColors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row: label + northeast icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.dashboard.myBalance,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.north_east,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Balance amount
          Text(
            AppFormats.formatFromChf(data.currentBalance),
            style: GoogleFonts.robotoMono(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${AppStrings.dashboard.monthlySpendingRatio}: ${AppFormats.formatFromChfCompact(spent)} / ${AppFormats.formatFromChfCompact(monthlyLimit)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: LinearProgressIndicator(
              value: usageRatio,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation(
                usageRatio > 0.9 ? AppColors.danger : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
