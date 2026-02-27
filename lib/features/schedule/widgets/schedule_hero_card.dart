import 'package:flutter/material.dart';
import 'package:solver/core/l10n/app_strings.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_premium_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/shared/widgets/mini_sparkline.dart';
import 'package:solver/shared/widgets/overdue_badge.dart';
import 'package:solver/shared/widgets/premium_amount_text.dart';
import 'package:solver/shared/widgets/premium_card_base.dart';

/// Hero card for the schedule page.
/// Shows: total due, period label, overdue badge, sparkline.
/// Gradient switches to warmthGradient when hasOverdue = true.
class ScheduleHeroCard extends StatelessWidget {
  final double totalDue;
  final String period;
  final int overdueCount;
  final bool hasOverdue;
  final List<double> sparklineData;
  final String currencyCode;

  const ScheduleHeroCard({
    super.key,
    required this.totalDue,
    required this.period,
    required this.overdueCount,
    required this.hasOverdue,
    required this.sparklineData,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.extension<PremiumThemeExtension>()!;
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    final gradient = hasOverdue ? p.warmthGradient : p.heroCardGradient;
    final glowColor = hasOverdue ? AppColors.danger : AppColors.primary;

    return PremiumCardBase(
      variant: PremiumCardVariant.hero,
      overrideGradient: gradient,
      showGlow: hasOverdue,
      glowColor: glowColor,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.xl,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Left: label + amount + badge ──────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${AppStrings.schedule.totalToPay} – $period',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: (isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight)
                        .withAlpha(140),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                PremiumAmountText(
                  amount: totalDue,
                  currency: currencyCode,
                  variant: PremiumAmountVariant.hero,
                  overrideColor: textPrimary,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppStrings.schedule.monthInvoices,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (overdueCount > 0) ...[
                  const SizedBox(height: AppSpacing.md),
                  OverdueBadge(count: overdueCount),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          // ── Right: sparkline ──────────────────────────────────────────────
          if (sparklineData.length >= 2)
            SizedBox(
              width: 90,
              height: 48,
              child: MiniSparkline(
                data: sparklineData,
                color: hasOverdue
                    ? AppColors.danger.withAlpha(200)
                    : AppColors.primary.withAlpha(200),
                strokeWidth: 2.0,
              ),
            ),
        ],
      ),
    );
  }
}
