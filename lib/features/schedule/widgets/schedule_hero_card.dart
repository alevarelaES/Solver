import 'package:flutter/material.dart';
import 'package:solver/core/l10n/app_strings.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_premium_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/shared/widgets/premium_amount_text.dart';
import 'package:solver/shared/widgets/premium_card_base.dart';

/// Hero card for the schedule page.
/// Shows total to pay + overdue badge. No sparkline (removed per design).
class ScheduleHeroCard extends StatelessWidget {
  final double totalDue;
  final String period;
  final int overdueCount;
  final bool hasOverdue;
  final String currencyCode;

  const ScheduleHeroCard({
    super.key,
    required this.totalDue,
    required this.period,
    required this.overdueCount,
    required this.hasOverdue,
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        // mainAxisSize.min est obligatoire dans un contexte scrollable.
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Overdue badge (top) ──────────────────────────────────────────
          if (hasOverdue) ...[
            Align(
              alignment: Alignment.topRight,
              child: _HeroBadge(
                monthLabel: AppStrings.schedule.monthInvoices,
                overdueCount: overdueCount,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          // ── Amount ────────────────────────────────────────────────────────
          PremiumAmountText(
            amount: totalDue,
            currency: currencyCode,
            variant: PremiumAmountVariant.hero,
            overrideColor: textPrimary,
          ),
          const SizedBox(height: 4),
          // ── Period label ─────────────────────────────────────────────────
          Text(
            'TOTAL À PAYER – $period',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textPrimary.withAlpha(140),
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  final String monthLabel;
  final int overdueCount;

  const _HeroBadge({required this.monthLabel, required this.overdueCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.danger.withAlpha(28),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: AppColors.danger.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 12,
            color: AppColors.danger,
          ),
          const SizedBox(width: 5),
          Text(
            '$monthLabel · $overdueCount en retard',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}
