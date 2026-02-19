import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/theme/app_component_styles.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/core/settings/currency_settings_provider.dart';
import 'package:solver/features/schedule/providers/schedule_provider.dart';
import 'package:solver/features/transactions/models/transaction.dart';
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
        error: (_, _) => const SizedBox(
          height: 120,
          child: Center(
            child: Text(
              'Impossible de charger les factures',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ),
        data: (data) {
          final source = _showAll
              ? [...data.manual, ...data.auto]
              : data.manual;
          final invoices = source.where((t) {
            if (t.amount <= 0) return false;
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
                          'Factures a traiter',
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
                      _showAll ? 'Manuelles' : 'Tout afficher',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
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
                              ? 'ALERTE: $overdueCount facture${overdueCount > 1 ? 's' : ''} en retard'
                              : 'Attention: $dueTodayCount facture${dueTodayCount > 1 ? 's' : ''} echeance aujourd\'hui',
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
                    ? 'Aucune facture en attente'
                    : '$urgentCount prioritaire${urgentCount > 1 ? 's' : ''} sur ${invoices.length} facture${invoices.length > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (invoices.isEmpty)
                const SizedBox(
                  height: 140,
                  child: Center(
                    child: Text(
                      'Rien a traiter pour le moment',
                      style: TextStyle(fontSize: 12),
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
                          onTap: () => context.go('/schedule'),
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
}
