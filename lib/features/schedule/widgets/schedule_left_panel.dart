import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/l10n/app_strings.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/schedule/providers/schedule_provider.dart';
import 'package:solver/features/transactions/models/transaction.dart';
import 'package:solver/features/transactions/providers/transaction_refresh.dart';
import 'package:solver/shared/widgets/mini_month_calendar.dart';
import 'package:solver/shared/widgets/premium_card_base.dart';

/// Left panel (fixed width) of the schedule Stat tab.
/// Shows: upcoming invoices summary + mini month calendar.
/// Tapping a day on the calendar shows a centered dialog with that day's invoices.
class ScheduleLeftPanel extends StatelessWidget {
  final double totalManual;
  final double totalAuto;
  final String currencyCode;

  /// All upcoming transactions (auto + manual), used to mark calendar dates
  /// and populate the day detail popup.
  final List<Transaction> allTransactions;

  const ScheduleLeftPanel({
    super.key,
    required this.totalManual,
    required this.totalAuto,
    required this.currencyCode,
    required this.allTransactions,
  });

  // ── Day detail popup ───────────────────────────────────────────────────────

  void _showDayDetail(BuildContext context, DateTime day) {
    final dayTxs = allTransactions.where((t) {
      final d = DateTime(t.date.year, t.date.month, t.date.day);
      return d == day;
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    showDialog<void>(
      context: context,
      builder: (_) => _DayDetailDialog(
        day: day,
        transactions: dayTxs,
        currencyCode: currencyCode,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final scheduledDates = allTransactions
        .where(
          (t) =>
              t.isPending &&
              !DateTime(t.date.year, t.date.month, t.date.day).isBefore(today),
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
          _UpcomingInvoicesSummary(
            totalManual: totalManual,
            totalAuto: totalAuto,
            currencyCode: currencyCode,
          ),
          const SizedBox(height: AppSpacing.md),
          MiniMonthCalendar(
            initialMonth: DateTime(now.year, now.month),
            scheduledDates: scheduledDates,
            overdueDates: overdueDates,
            onDayTapped: (day) => _showDayDetail(context, day),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Day detail — centered dialog with Pay button
// ─────────────────────────────────────────────────────────────────────────────

class _DayDetailDialog extends ConsumerStatefulWidget {
  final DateTime day;
  final List<Transaction> transactions;
  final String currencyCode;

  const _DayDetailDialog({
    required this.day,
    required this.transactions,
    required this.currencyCode,
  });

  @override
  ConsumerState<_DayDetailDialog> createState() => _DayDetailDialogState();
}

class _DayDetailDialogState extends ConsumerState<_DayDetailDialog> {
  final Map<String, bool> _loading = {};

  Future<void> _pay(Transaction t) async {
    setState(() => _loading[t.id] = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.put(
        '/api/transactions/${t.id}',
        data: {
          'accountId': t.accountId,
          'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'amount': t.amount,
          'note': t.note,
          'status': 0,
          'isAuto': t.isAuto,
        },
      );
      invalidateAfterTransactionMutation(ref);
      ref.invalidate(upcomingTransactionsProvider);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _loading[t.id] = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final label = DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(widget.day);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label[0].toUpperCase() + label.substring(1),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Divider(color: AppColors.borderSubtle),
              const SizedBox(height: AppSpacing.sm),
              // Content
              if (widget.transactions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 28,
                          color: AppColors.textDisabled,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          'Aucune échéance ce jour-là',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...widget.transactions.map(
                  (t) => _DayTransactionRow(
                    transaction: t,
                    day: widget.day,
                    currencyCode: widget.currencyCode,
                    titleColor: titleColor,
                    loading: _loading[t.id] ?? false,
                    onPay: t.isPending && !t.isAuto ? () => _pay(t) : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Day transaction row (inside the dialog)
// ─────────────────────────────────────────────────────────────────────────────

class _DayTransactionRow extends StatelessWidget {
  final Transaction transaction;
  final DateTime day;
  final String currencyCode;
  final Color titleColor;
  final bool loading;
  final VoidCallback? onPay;

  const _DayTransactionRow({
    required this.transaction,
    required this.day,
    required this.currencyCode,
    required this.titleColor,
    required this.loading,
    this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final isOverdue = !t.isAuto && t.isPending && day.isBefore(todayOnly);

    final color = t.isCompleted
        ? AppColors.textDisabled
        : isOverdue
            ? AppColors.danger
            : t.isAuto
                ? AppColors.primary
                : AppColors.warning;

    final statusLabel = t.isCompleted
        ? AppStrings.schedule.paid
        : isOverdue
            ? AppStrings.schedule.overdueLabel(
                todayOnly.difference(day).inDays,
              )
            : t.isAuto
                ? AppStrings.schedule.sectionAuto
                : AppStrings.schedule.sectionManual;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(
              t.isAuto ? Icons.bolt : Icons.description_outlined,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.accountName ?? t.accountId,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: t.isCompleted ? AppColors.textDisabled : titleColor,
                    decoration:
                        t.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            AppFormats.formatFromCurrency(t.amount, currencyCode),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          if (onPay != null) ...[
            const SizedBox(width: AppSpacing.sm),
            loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : SizedBox(
                    height: 28,
                    child: FilledButton(
                      onPressed: onPay,
                      style: ButtonStyle(
                        backgroundColor: WidgetStatePropertyAll(
                          color.withAlpha(25),
                        ),
                        foregroundColor: WidgetStatePropertyAll(color),
                        overlayColor: WidgetStatePropertyAll(
                          color.withAlpha(15),
                        ),
                        side: WidgetStatePropertyAll(
                          BorderSide(color: color.withAlpha(70)),
                        ),
                        padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        ),
                        minimumSize: const WidgetStatePropertyAll(
                          Size(0, 28),
                        ),
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                        ),
                        textStyle: const WidgetStatePropertyAll(
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                        elevation: const WidgetStatePropertyAll(0),
                      ),
                      child: const Text('Payer'),
                    ),
                  ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Upcoming invoices summary card
// ─────────────────────────────────────────────────────────────────────────────

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
    final total = totalManual + totalAuto;
    final progress =
        total > 0 ? (totalManual / total).clamp(0.0, 1.0) : 0.0;

    return PremiumCardBase(
      variant: PremiumCardVariant.standard,
      padding: AppSpacing.paddingCardCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppStrings.schedule.upcomingInvoices.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Manuelles & automatiques',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.textDisabled,
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
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: AppColors.primary.withAlpha(30),
              valueColor: const AlwaysStoppedAnimation(AppColors.warning),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _SummaryRow(
            icon: Icons.bolt,
            label: AppStrings.schedule.sectionAuto,
            amount: totalAuto,
            currencyCode: currencyCode,
            color: AppColors.primary,
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
