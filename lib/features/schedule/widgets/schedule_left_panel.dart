import 'package:flutter/material.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/l10n/app_strings.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/transactions/models/transaction.dart';
import 'package:solver/shared/widgets/mini_month_calendar.dart';
import 'package:solver/shared/widgets/premium_card_base.dart';
import 'package:solver/features/schedule/widgets/schedule_hero_card.dart';

/// Left panel (fixed width) of the schedule Stat tab.
/// Shows: upcoming invoices summary + mini month calendar.
class ScheduleLeftPanel extends StatelessWidget {
  final double totalManual;
  final double totalAuto;
  final String currencyCode;

  /// All upcoming transactions (auto + manual), used to mark calendar dates.
  final List<Transaction> allTransactions;

  // Hero card properties
  final double totalDue;
  final String period;
  final int overdueCount;
  final bool hasOverdue;
  final List<double> sparklineData;

  const ScheduleLeftPanel({
    super.key,
    required this.totalManual,
    required this.totalAuto,
    required this.currencyCode,
    required this.allTransactions,
    required this.totalDue,
    required this.period,
    required this.overdueCount,
    required this.hasOverdue,
    required this.sparklineData,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Build event dates for the calendar
    final scheduledDates = allTransactions
        .where(
          (t) => t.isPending && !DateTime(t.date.year, t.date.month, t.date.day).isBefore(today),
        )
        .map((t) => DateTime(t.date.year, t.date.month, t.date.day))
        .toSet()
        .toList();

    final overdueDates = allTransactions
        .where(
          (t) =>
              !t.isAuto &&
              t.isPending &&
              DateTime(t.date.year, t.date.month, t.date.day).isBefore(today),
        )
        .map((t) => DateTime(t.date.year, t.date.month, t.date.day))
        .toSet()
        .toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Hero card ─────────────────────────────────────────
          ScheduleHeroCard(
            totalDue: totalDue,
            period: period,
            overdueCount: overdueCount,
            hasOverdue: hasOverdue,
            sparklineData: sparklineData,
            currencyCode: currencyCode,
          ),
          const SizedBox(height: AppSpacing.md),
          // ── Upcoming invoices summary ────────────────────────────────────
          _UpcomingInvoicesSummary(
            totalManual: totalManual,
            totalAuto: totalAuto,
            currencyCode: currencyCode,
          ),
          const SizedBox(height: AppSpacing.md),
          // ── Mini month calendar ─────────────────────────────────────────
          MiniMonthCalendar(
            initialMonth: DateTime(now.year, now.month),
            scheduledDates: scheduledDates,
            overdueDates: overdueDates,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Upcoming invoices summary card
// ---------------------------------------------------------------------------
class _UpcomingInvoicesSummary extends StatelessWidget {
  final double totalManual;
  final double totalAuto;
  final String currencyCode;

  const _UpcomingInvoicesSummary({
    required this.totalManual,
    required this.totalAuto,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCardBase(
      variant: PremiumCardVariant.standard,
      padding: AppSpacing.paddingCardCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Section header
          Text(
            AppStrings.schedule.upcomingInvoices.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: AppSpacing.sm),
          _SummaryRow(
            icon: Icons.description_outlined,
            label: AppStrings.schedule.sectionManual,
            amount: totalManual,
            currencyCode: currencyCode,
            color: AppColors.warning,
          ),
          const SizedBox(height: AppSpacing.sm),
          _SummaryRow(
            icon: Icons.bolt,
            label: AppStrings.schedule.sectionAuto,
            amount: totalAuto,
            currencyCode: currencyCode,
            color: AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: AppSpacing.sm),
          // Total row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                AppFormats.formatFromCurrency(totalManual + totalAuto, currencyCode),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double amount;
  final String currencyCode;
  final Color color;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.amount,
    required this.currencyCode,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          AppFormats.formatFromCurrency(amount, currencyCode),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
