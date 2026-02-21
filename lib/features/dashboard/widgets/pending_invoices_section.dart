import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/providers/navigation_providers.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/core/theme/app_component_styles.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/core/settings/currency_settings_provider.dart';
import 'package:solver/features/schedule/providers/schedule_provider.dart';
import 'package:solver/features/transactions/models/transaction.dart';
import 'package:solver/features/transactions/providers/transaction_refresh.dart';
import 'package:solver/core/l10n/app_strings.dart';
import 'package:solver/shared/widgets/glass_container.dart';

class PendingInvoicesSection extends ConsumerStatefulWidget {
  const PendingInvoicesSection({super.key});

  @override
  ConsumerState<PendingInvoicesSection> createState() =>
      _PendingInvoicesSectionState();
}

class _PendingInvoicesSectionState
    extends ConsumerState<PendingInvoicesSection> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    ref.watch(appCurrencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final upcomingAsync = ref.watch(upcomingTransactionsProvider);

    return GlassContainer(
      padding: AppSpacing.paddingCardCompact,
      child: upcomingAsync.when(
        loading: () => const SizedBox(
          height: 180,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => SizedBox(
          height: 120,
          child: Center(
            child: Text(
              AppStrings.dashboard.invoicesLoadError,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ),
        data: (data) {
          final source = _showAll
              ? [...data.manual, ...data.auto]
              : data.manual;
          final invoices = source.where((t) {
            if (t.amount <= 0) return false;
            if (!t.isPending) return false;
            final days = _daysUntil(t.date);
            // Keep overdue bills, and upcoming bills due in the next 30 days.
            return days <= 30;
          }).toList()..sort(_compareByPriority);

          final overdueCount = invoices
              .where((t) => _daysUntil(t.date) < 0)
              .length;
          final dueTodayCount = invoices
              .where((t) => _daysUntil(t.date) == 0)
              .length;
          final urgentCount = invoices
              .where((t) => _daysUntil(t.date) <= 3)
              .length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          AppStrings.dashboard.pendingInvoices,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        if (overdueCount > 0) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(AppRadius.xs),
                              border: Border.all(
                                color: AppColors.danger.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              '$overdueCount retard${overdueCount > 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.danger,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _showAll = !_showAll),
                    style: AppButtonStyles.inline(),
                    child: Text(
                      _showAll
                          ? AppStrings.dashboard.manualOnly
                          : AppStrings.dashboard.showAll,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  AppStrings.dashboard.pendingInvoicesHint,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark
                        ? AppColors.textDisabledDark
                        : AppColors.textDisabledLight,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (overdueCount > 0 || dueTodayCount > 0)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(
                      alpha: isDark ? 0.2 : 0.1,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: AppColors.danger,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          overdueCount > 0
                              ? AppStrings.dashboard.overdueAlert(overdueCount)
                              : AppStrings.dashboard.todayAlert(dueTodayCount),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                invoices.isEmpty
                    ? AppStrings.dashboard.noPending
                    : AppStrings.dashboard.invoicesPriority(
                        urgentCount,
                        invoices.length,
                      ),
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (invoices.isEmpty)
                SizedBox(
                  height: 140,
                  child: Center(
                    child: Text(
                      AppStrings.dashboard.nothingToDo,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 200),
                  child: Column(
                    children: invoices.take(4).map((t) {
                      final days = _daysUntil(t.date);
                      final color = _priorityColor(days);
                      final isOverdue = days < 0;
                      final isToday = days == 0;
                      final rowAccent = isOverdue
                          ? AppColors.danger
                          : isToday
                          ? AppColors.warningDeep
                          : color;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: GestureDetector(
                          onTap: () => _openInvoiceDetails(t),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(AppRadius.sm),
                                ),
                                border: Border.all(
                                  color: rowAccent.withValues(alpha: 0.45),
                                ),
                                color: rowAccent.withValues(
                                  alpha: isDark ? 0.2 : 0.08,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: rowAccent,
                                      borderRadius: const BorderRadius.all(
                                        Radius.circular(AppRadius.xs),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            if (days <= 0) ...[
                                              Icon(
                                                Icons.priority_high_rounded,
                                                size: 14,
                                                color: rowAccent,
                                              ),
                                              const SizedBox(width: 4),
                                            ],
                                            Expanded(
                                              child: Text(
                                                t.accountName ?? 'Facture',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: isDark
                                                      ? AppColors
                                                            .textPrimaryDark
                                                      : AppColors
                                                            .textPrimaryLight,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          '${_priorityLabel(days)} - ${_daysLabel(days)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: days <= 0
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: rowAccent,
                                          ),
                                        ),
                                        Text(
                                          'Echeance: ${DateFormat('dd MMM yyyy', 'fr_CH').format(t.date)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isDark
                                                ? AppColors.textSecondaryDark
                                                : AppColors.textSecondaryLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    AppFormats.formatFromChfCompact(t.amount),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: days <= 0
                                          ? rowAccent
                                          : (isDark
                                                ? AppColors.textPrimaryDark
                                                : AppColors.textPrimaryLight),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  int _compareByPriority(Transaction a, Transaction b) {
    final dayDiff = _daysUntil(a.date).compareTo(_daysUntil(b.date));
    if (dayDiff != 0) return dayDiff;
    return b.amount.compareTo(a.amount);
  }

  int _daysUntil(DateTime date) {
    final today = DateUtils.dateOnly(DateTime.now());
    final due = DateUtils.dateOnly(date);
    return due.difference(today).inDays;
  }

  Color _priorityColor(int days) {
    if (days <= -14) return AppColors.dangerDeep;
    if (days <= -7) return AppColors.dangerStrong;
    if (days <= -1) return AppColors.danger;
    if (days == 0) return AppColors.warningDeep;
    if (days <= 3) return AppColors.warning;
    if (days <= 7) return AppColors.warningBright;
    if (days <= 14) return AppColors.successLime;
    return AppColors.primary;
  }

  String _priorityLabel(int days) {
    if (days <= 0) return 'Urgent';
    if (days <= 3) return 'Tres urgent';
    if (days <= 10) return 'Prioritaire';
    return 'A venir';
  }

  String _daysLabel(int days) {
    if (days < 0) {
      final late = days.abs();
      return 'En retard de $late jour${late > 1 ? 's' : ''}';
    }
    if (days == 0) return 'Echeance aujourd\'hui';
    if (days == 1) return 'Dans 1 jour';
    return 'Dans $days jours';
  }

  void _openInvoiceInJournal(Transaction transaction) {
    ref.read(pendingJournalTxIdProvider.notifier).state = transaction.id;
    if (!mounted) return;
    context.go('/journal');
  }

  Future<void> _markAsPaid(Transaction transaction) async {
    final client = ref.read(apiClientProvider);
    // status 0 = completed (mapped from Transaction.isCompleted on backend)
    const completedStatus = 0;
    await client.put(
      '/api/transactions/${transaction.id}',
      data: {
        'accountId': transaction.accountId,
        'date': DateFormat('yyyy-MM-dd').format(transaction.date),
        'amount': transaction.amount,
        'note': transaction.note,
        'status': completedStatus,
        'isAuto': transaction.isAuto,
      },
    );
    invalidateAfterTransactionMutation(ref);
  }

  Future<void> _openInvoiceDetails(Transaction transaction) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final days = _daysUntil(transaction.date);
    final isOverdue = days < 0;
    final canSettle = transaction.isPending && !transaction.isAuto;
    var loading = false;
    var actionError = '';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Dialog(
              backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 560,
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.xl,
                      AppSpacing.xl,
                      AppSpacing.lg,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.accountName ?? 'Facture',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${DateFormat('dd MMM yyyy', 'fr_CH').format(transaction.date)} - ${_daysLabel(days)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isOverdue
                                ? AppColors.danger
                                : (isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          AppFormats.formatFromChf(transaction.amount),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          children: [
                            _DetailChip(
                              label: transaction.isAuto
                                  ? AppStrings.dashboard.autoDebit
                                  : AppStrings.dashboard.manualInvoice,
                            ),
                            _DetailChip(
                              label: transaction.isPending
                                  ? AppStrings.dashboard.statusPending
                                  : AppStrings.dashboard.statusPaid,
                            ),
                            if ((transaction.categoryGroup ?? '').isNotEmpty)
                              _DetailChip(label: transaction.categoryGroup!),
                          ],
                        ),
                        if ((transaction.note ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            transaction.note!,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                        if (actionError.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            actionError,
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: [
                            if (canSettle) ...[
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: loading
                                      ? null
                                      : () async {
                                          setSheetState(() {
                                            loading = true;
                                            actionError = '';
                                          });
                                          try {
                                            await _markAsPaid(transaction);
                                            if (!dialogContext.mounted) return;
                                            Navigator.of(dialogContext).pop();
                                          } catch (_) {
                                            setSheetState(() {
                                              loading = false;
                                              actionError =
                                                  AppStrings.dashboard.settleError;
                                            });
                                          }
                                        },
                                  icon: loading
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.check_circle_outline,
                                          size: 16,
                                        ),
                                  label: Text(AppStrings.dashboard.settleInvoice),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                            ],
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: loading
                                    ? null
                                    : () {
                                        Navigator.of(dialogContext).pop();
                                        _openInvoiceInJournal(transaction);
                                      },
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: Text(AppStrings.dashboard.openTransactions),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String label;

  const _DetailChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.textPrimaryDark : AppColors.primary,
        ),
      ),
    );
  }
}
