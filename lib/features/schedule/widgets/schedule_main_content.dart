import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/l10n/app_strings.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_premium_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/schedule/widgets/schedule_empty_state.dart';
import 'package:solver/shared/widgets/premium_card_base.dart';
import 'package:solver/features/transactions/models/transaction.dart';
import 'package:solver/features/transactions/providers/transaction_refresh.dart';
import 'package:solver/features/schedule/widgets/schedule_header_controls.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ScheduleMainContent
// ─────────────────────────────────────────────────────────────────────────────

/// Main content column for the schedule Stat tab.
/// Shows period toggle + two invoice sections (manual + auto).
class ScheduleMainContent extends ConsumerWidget {
  final List<Transaction> autoList;
  final List<Transaction> manualList;
  final double totalAuto;
  final double totalManual;
  final String currencyCode;
  final VoidCallback onChanged;

  final SchedulePeriodScope periodScope;
  final ValueChanged<SchedulePeriodScope> onPeriodChanged;

  const ScheduleMainContent({
    super.key,
    required this.autoList,
    required this.manualList,
    required this.totalAuto,
    required this.totalManual,
    required this.currencyCode,
    required this.onChanged,
    required this.periodScope,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.sizeOf(context).width >= 960;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Period control ─────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ScheduleHeaderControls(
              periodScope: periodScope,
              onPeriodChanged: onPeriodChanged,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        // ── Invoice sections ───────────────────────────────────────────────
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _InvoiceSection(
                  title: AppStrings.schedule.sectionManual,
                  icon: Icons.description_outlined,
                  accentColor: AppColors.warning,
                  transactions: manualList,
                  showValidate: true,
                  currencyCode: currencyCode,
                  onChanged: onChanged,
                  totalAmount: totalManual,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: _InvoiceSection(
                  title: AppStrings.schedule.sectionAuto,
                  icon: Icons.bolt,
                  accentColor: AppColors.primary,
                  transactions: autoList,
                  showValidate: false,
                  currencyCode: currencyCode,
                  onChanged: onChanged,
                  totalAmount: totalAuto,
                ),
              ),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InvoiceSection(
                title: AppStrings.schedule.sectionManual,
                icon: Icons.description_outlined,
                accentColor: AppColors.warning,
                transactions: manualList,
                showValidate: true,
                currencyCode: currencyCode,
                onChanged: onChanged,
                totalAmount: totalManual,
              ),
              const SizedBox(height: AppSpacing.xl),
              _InvoiceSection(
                title: AppStrings.schedule.sectionAuto,
                icon: Icons.bolt,
                accentColor: AppColors.primary,
                transactions: autoList,
                showValidate: false,
                currencyCode: currencyCode,
                onChanged: onChanged,
                totalAmount: totalAuto,
              ),
            ],
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Invoice section
// ─────────────────────────────────────────────────────────────────────────────

class _InvoiceSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final List<Transaction> transactions;
  final bool showValidate;
  final String currencyCode;
  final VoidCallback onChanged;
  final double totalAmount;

  const _InvoiceSection({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.transactions,
    required this.showValidate,
    required this.currencyCode,
    required this.onChanged,
    required this.totalAmount,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCardBase(
      variant: PremiumCardVariant.standard,
      padding: AppSpacing.paddingCardCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section header ───────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(icon, color: accentColor, size: 16),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (transactions.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${transactions.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                AppFormats.formatFromCurrency(totalAmount, currencyCode),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: AppSpacing.md),
          // ── Invoice list or empty state ───────────────────────────────────
          if (transactions.isEmpty)
            ScheduleEmptyState(accentColor: accentColor)
          else
            ...transactions.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: ScheduleInvoiceCard(
                  transaction: t,
                  accentColor: accentColor,
                  showValidate: showValidate,
                  currencyCode: currencyCode,
                  onChanged: onChanged,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Invoice card
// ─────────────────────────────────────────────────────────────────────────────

class ScheduleInvoiceCard extends ConsumerStatefulWidget {
  final Transaction transaction;
  final Color accentColor;
  final bool showValidate;
  final String currencyCode;
  final VoidCallback onChanged;

  const ScheduleInvoiceCard({
    super.key,
    required this.transaction,
    required this.accentColor,
    required this.showValidate,
    required this.currencyCode,
    required this.onChanged,
  });

  @override
  ConsumerState<ScheduleInvoiceCard> createState() => _ScheduleInvoiceCardState();
}

class _ScheduleInvoiceCardState extends ConsumerState<ScheduleInvoiceCard> {
  bool _loading = false;
  bool _isHovering = false;

  Transaction get _tx => widget.transaction;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _dueDateOnly {
    final d = _tx.date;
    return DateTime(d.year, d.month, d.day);
  }

  bool get _isOverdue =>
      !_tx.isAuto && _tx.isPending && _dueDateOnly.isBefore(_today);

  bool get _isDueToday =>
      _tx.isPending && _dueDateOnly.isAtSameMomentAs(_today);

  int get _daysUntilDue => _dueDateOnly.difference(_today).inDays;

  bool get _isUrgent =>
      !_tx.isCompleted &&
      (_isOverdue || _isDueToday || (_daysUntilDue >= 0 && _daysUntilDue <= 7));

  Color get _cardColor {
    if (_isOverdue) return AppColors.danger;
    if (_daysUntilDue >= 0 && _daysUntilDue <= 7) return AppColors.warning;
    return widget.accentColor;
  }

  String get _timingLabel {
    if (_tx.isCompleted) return AppStrings.schedule.paid;
    if (_isOverdue) {
      final days = _today.difference(_dueDateOnly).inDays;
      return AppStrings.schedule.overdueLabel(days);
    }
    if (_isDueToday) return AppStrings.schedule.dueToday();
    return AppStrings.schedule.daysUntil(_daysUntilDue);
  }

  Future<void> _validate() async {
    setState(() => _loading = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.put(
        '/api/transactions/${_tx.id}',
        data: {
          'accountId': _tx.accountId,
          'date': DateFormat('yyyy-MM-dd').format(
            _tx.isAuto ? _tx.date : DateTime.now(),
          ),
          'amount': _tx.amount,
          'note': _tx.note,
          'status': 0,
          'isAuto': _tx.isAuto,
        },
      );
      invalidateAfterTransactionMutation(ref);
      widget.onChanged();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.extension<PremiumThemeExtension>()!;
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final cardColor = _cardColor;

    Color cardSurface;
    if (_tx.isCompleted) {
      cardSurface = p.glassSurface;
    } else if (_isOverdue) {
      cardSurface = AppColors.danger.withAlpha(8);
    } else if (_isHovering) {
      cardSurface = cardColor.withAlpha(18);
    } else {
      cardSurface = p.glassSurface;
    }

    final borderColor = _isHovering
        ? cardColor.withAlpha(90)
        : _isUrgent
            ? cardColor.withAlpha(55)
            : p.glassBorder;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _isHovering ? -2.0 : 0, 0),
        decoration: BoxDecoration(
          color: cardSurface,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(_isHovering ? 16 : 8),
              blurRadius: _isHovering ? 16 : 8,
              offset: Offset(0, _isHovering ? 6 : 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xxl - 1),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left accent bar (pending only)
                if (!_tx.isCompleted)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 170),
                    width: 4,
                    color: cardColor,
                  ),
                // Main content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: [
                        // Icon badge
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _tx.isCompleted
                                ? AppColors.surfaceHeader
                                : cardColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                          child: Icon(
                            _isOverdue
                                ? Icons.schedule_rounded
                                : _iconForTransaction(_tx),
                            color: _tx.isCompleted
                                ? AppColors.textDisabled
                                : cardColor,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        // Name + timing
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _tx.accountName ?? _tx.accountId,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _tx.isCompleted
                                      ? AppColors.textDisabled
                                      : textPrimary,
                                  decoration: _tx.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${DateFormat('dd MMM yyyy', 'fr_FR').format(_tx.date)} · $_timingLabel',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: _isUrgent
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: _isUrgent
                                      ? cardColor
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        // Amount + pay button
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              AppFormats.formatFromCurrency(
                                _tx.amount,
                                widget.currencyCode,
                              ),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: _tx.isCompleted
                                    ? AppColors.textDisabled
                                    : _isOverdue
                                        ? cardColor
                                        : textPrimary,
                              ),
                            ),
                            if (widget.showValidate && !_tx.isCompleted) ...[
                              const SizedBox(height: AppSpacing.sm),
                              _loading
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: cardColor,
                                      ),
                                    )
                                  : SizedBox(
                                      height: 28,
                                      child: FilledButton.tonal(
                                        onPressed: _validate,
                                        style: ButtonStyle(
                                          backgroundColor:
                                              WidgetStatePropertyAll(
                                            cardColor.withAlpha(25),
                                          ),
                                          foregroundColor:
                                              WidgetStatePropertyAll(cardColor),
                                          overlayColor: WidgetStatePropertyAll(
                                            cardColor.withAlpha(15),
                                          ),
                                          side: WidgetStatePropertyAll(
                                            BorderSide(
                                              color: cardColor.withAlpha(70),
                                            ),
                                          ),
                                          padding: const WidgetStatePropertyAll(
                                            EdgeInsets.symmetric(
                                              horizontal: AppSpacing.md,
                                            ),
                                          ),
                                          minimumSize:
                                              const WidgetStatePropertyAll(
                                            Size(0, 28),
                                          ),
                                          shape: WidgetStatePropertyAll(
                                            RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                AppRadius.r10,
                                              ),
                                            ),
                                          ),
                                          textStyle:
                                              const WidgetStatePropertyAll(
                                            TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          elevation:
                                              const WidgetStatePropertyAll(0),
                                        ),
                                        child: Text(
                                          _isOverdue
                                              ? AppStrings.schedule.pay
                                              : AppStrings.schedule.validate,
                                        ),
                                      ),
                                    ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForTransaction(Transaction t) {
    final lower = (t.accountName ?? '').toLowerCase();
    if (lower.contains('loyer') || lower.contains('rent')) {
      return Icons.home_outlined;
    }
    if (lower.contains('transport') ||
        lower.contains('bus') ||
        lower.contains('train')) {
      return Icons.directions_bus_outlined;
    }
    if (lower.contains('assur')) return Icons.shield_outlined;
    if (lower.contains('telecom') ||
        lower.contains('swisscom') ||
        lower.contains('wifi') ||
        lower.contains('internet')) {
      return Icons.wifi;
    }
    if (lower.contains('netflix') || lower.contains('spotify')) {
      return Icons.play_circle_outline;
    }
    if (lower.contains('impot') || lower.contains('tax')) {
      return Icons.account_balance_outlined;
    }
    if (lower.contains('electr') || lower.contains('energie')) {
      return Icons.bolt;
    }
    return Icons.receipt_long_outlined;
  }
}
