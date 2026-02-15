import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/features/schedule/providers/schedule_provider.dart';
import 'package:solver/features/transactions/models/transaction.dart';
import 'package:solver/features/transactions/providers/transaction_refresh.dart';

// -- View toggle -------------------------------------------------------------
final _calendarModeProvider = StateProvider<bool>(
  (ref) => false,
); // false = list

enum _InvoiceScope { month, all }

final _invoiceScopeProvider = StateProvider<_InvoiceScope>(
  (ref) => _InvoiceScope.month,
);
final _calendarMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

// -- Colours -----------------------------------------------------------------
const _autoColor = AppColors.primary;
const _manualColor = Color(0xFFF97316); // orange
const _overdueColor = AppColors.danger;
const _calendarAccent = Color(0xFF4C9A2A);
const _calendarAutoColor = Color(0xFF4C9A2A);
const _calendarManualColor = Color(0xFFEA7A1D);

class _ScopedUpcomingData {
  final List<Transaction> autoAll;
  final List<Transaction> manualAll;
  final List<Transaction> autoList;
  final List<Transaction> manualList;
  final int hiddenAuto;
  final int hiddenManual;
  final double totalAuto;
  final double totalManual;
  final double grandTotal;

  const _ScopedUpcomingData({
    required this.autoAll,
    required this.manualAll,
    required this.autoList,
    required this.manualList,
    required this.hiddenAuto,
    required this.hiddenManual,
    required this.totalAuto,
    required this.totalManual,
    required this.grandTotal,
  });
}

_ScopedUpcomingData _scopeUpcomingData(UpcomingData data, _InvoiceScope scope) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  bool isPast(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.isBefore(today);
  }

  bool isCurrentMonth(Transaction t) =>
      t.date.year == now.year && t.date.month == now.month;

  var autoAll = [...data.auto];
  var manualAll = [...data.manual];

  // Safety net: auto debits already past due should not be shown in schedule list.
  autoAll = autoAll
      .where((t) => !(t.isAuto && t.isPending && isPast(t.date)))
      .toList();

  autoAll.sort((a, b) => a.date.compareTo(b.date));
  manualAll.sort((a, b) => a.date.compareTo(b.date));

  if (scope == _InvoiceScope.month) {
    autoAll = autoAll.where(isCurrentMonth).toList();
    manualAll = manualAll.where(isCurrentMonth).toList();
  }

  final totalAuto = autoAll.fold<double>(0, (sum, t) => sum + t.amount);
  final totalManual = manualAll.fold<double>(0, (sum, t) => sum + t.amount);

  List<Transaction> autoList = autoAll;
  List<Transaction> manualList = manualAll;
  var hiddenAuto = 0;
  var hiddenManual = 0;

  if (scope == _InvoiceScope.all) {
    if (autoList.length > 10) {
      hiddenAuto = autoList.length - 10;
      autoList = autoList.take(10).toList();
    }
    if (manualList.length > 10) {
      hiddenManual = manualList.length - 10;
      manualList = manualList.take(10).toList();
    }
  }

  return _ScopedUpcomingData(
    autoAll: autoAll,
    manualAll: manualAll,
    autoList: autoList,
    manualList: manualList,
    hiddenAuto: hiddenAuto,
    hiddenManual: hiddenManual,
    totalAuto: totalAuto,
    totalManual: totalManual,
    grandTotal: totalAuto + totalManual,
  );
}

_ScopedUpcomingData _scopeUpcomingDataToMonth(
  _ScopedUpcomingData data,
  DateTime month,
) {
  bool inMonth(Transaction t) =>
      t.date.year == month.year && t.date.month == month.month;

  final auto = data.autoAll.where(inMonth).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  final manual = data.manualAll.where(inMonth).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  final totalAuto = auto.fold<double>(0, (sum, t) => sum + t.amount);
  final totalManual = manual.fold<double>(0, (sum, t) => sum + t.amount);

  return _ScopedUpcomingData(
    autoAll: auto,
    manualAll: manual,
    autoList: auto,
    manualList: manual,
    hiddenAuto: 0,
    hiddenManual: 0,
    totalAuto: totalAuto,
    totalManual: totalManual,
    grandTotal: totalAuto + totalManual,
  );
}

class ScheduleView extends ConsumerWidget {
  const ScheduleView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcomingAsync = ref.watch(upcomingTransactionsProvider);
    final isCalendar = ref.watch(_calendarModeProvider);
    final scope = ref.watch(_invoiceScopeProvider);
    final calendarMonth = ref.watch(_calendarMonthProvider);

    return upcomingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Erreur: $e',
          style: const TextStyle(color: AppColors.danger),
        ),
      ),
      data: (data) {
        final listData = _scopeUpcomingData(data, scope);
        final calendarData = _scopeUpcomingData(data, _InvoiceScope.all);
        final headerData = isCalendar
            ? _scopeUpcomingDataToMonth(calendarData, calendarMonth)
            : listData;
        final bodyData = isCalendar ? calendarData : listData;
        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: Column(
                    children: [
                      _HeroHeader(data: headerData),
                      const SizedBox(height: 24),
                      _Body(data: bodyData, maxWidth: constraints.maxWidth),
                      const SizedBox(height: 40),
                    ],
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

// -------------------------------------------------------------------------------
// HERO HEADER
// -------------------------------------------------------------------------------
class _HeroHeader extends ConsumerWidget {
  final _ScopedUpcomingData data;
  const _HeroHeader({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCalendar = ref.watch(_calendarModeProvider);
    final scope = ref.watch(_invoiceScopeProvider);
    final calendarMonth = ref.watch(_calendarMonthProvider);
    final isDesktop = MediaQuery.sizeOf(context).width >= 980;
    final now = isCalendar ? calendarMonth : DateTime.now();
    final monthLabel = DateFormat(
      'MMMM yyyy',
      'fr_FR',
    ).format(now).toUpperCase();

    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TOTAL A PAYER - $monthLabel',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.textDisabled,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppFormats.currency.format(data.grandTotal),
          style: const TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          isCalendar
              ? 'Calendrier du mois'
              : scope == _InvoiceScope.month
              ? 'Factures du mois'
              : 'Toutes les factures',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );

    final controlsPanel = _ControlsPanel(
      isCalendar: isCalendar,
      scope: scope,
      showScope: !isCalendar,
      onModeChanged: (calendar) =>
          ref.read(_calendarModeProvider.notifier).state = calendar,
      onScopeChanged: (nextScope) =>
          ref.read(_invoiceScopeProvider.notifier).state = nextScope,
    );

    if (!isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          summary,
          const SizedBox(height: 16),
          Align(alignment: Alignment.centerRight, child: controlsPanel),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: summary),
        const SizedBox(width: 16),
        controlsPanel,
      ],
    );
  }
}

class _ControlsPanel extends StatelessWidget {
  final bool isCalendar;
  final _InvoiceScope scope;
  final bool showScope;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<_InvoiceScope> onScopeChanged;

  const _ControlsPanel({
    required this.isCalendar,
    required this.scope,
    required this.showScope,
    required this.onModeChanged,
    required this.onScopeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD7DEE8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _FilterGroup(
            title: 'Vue',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ToggleChip(
                  label: 'Liste',
                  isActive: !isCalendar,
                  onTap: () => onModeChanged(false),
                ),
                _ToggleChip(
                  label: 'Calendrier',
                  isActive: isCalendar,
                  onTap: () => onModeChanged(true),
                ),
              ],
            ),
          ),
          if (showScope)
            _FilterGroup(
              title: 'Periode',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ToggleChip(
                    label: 'Mois',
                    isActive: scope == _InvoiceScope.month,
                    onTap: () => onScopeChanged(_InvoiceScope.month),
                  ),
                  _ToggleChip(
                    label: 'Toutes',
                    isActive: scope == _InvoiceScope.all,
                    onTap: () => onScopeChanged(_InvoiceScope.all),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterGroup extends StatelessWidget {
  final String title;
  final Widget child;

  const _FilterGroup({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _ToggleChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = isActive ? AppColors.primary : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? AppColors.primary.withAlpha(60)
                : Colors.transparent,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------------------
// BODY (switches list / calendar)
// -------------------------------------------------------------------------------
class _Body extends ConsumerWidget {
  final _ScopedUpcomingData data;
  final double maxWidth;
  const _Body({required this.data, required this.maxWidth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCalendar = ref.watch(_calendarModeProvider);
    if (isCalendar) {
      return _CalendarView(data: data);
    }
    return _ListViewBody(data: data, maxWidth: maxWidth);
  }
}

// -------------------------------------------------------------------------------
// LIST VIEW
// -------------------------------------------------------------------------------
class _ListViewBody extends ConsumerWidget {
  final _ScopedUpcomingData data;
  final double maxWidth;
  const _ListViewBody({required this.data, required this.maxWidth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = maxWidth > 960;
    final scope = ref.watch(_invoiceScopeProvider);
    final maxVisible = scope == _InvoiceScope.all ? 10 : null;
    void onChanged() => ref.invalidate(upcomingTransactionsProvider);

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _SectionColumn(
              title: 'Prelevements auto',
              icon: Icons.bolt,
              color: _autoColor,
              transactions: data.autoList,
              total: data.totalAuto,
              hiddenCount: data.hiddenAuto,
              maxVisible: maxVisible,
              showValidate: false,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: _SectionColumn(
              title: 'Factures manuelles',
              icon: Icons.description_outlined,
              color: _manualColor,
              transactions: data.manualList,
              total: data.totalManual,
              hiddenCount: data.hiddenManual,
              maxVisible: maxVisible,
              showValidate: true,
              onChanged: onChanged,
            ),
          ),
        ],
      );
    }

    // Mobile: stacked
    return Column(
      children: [
        _SectionColumn(
          title: 'Prelevements auto',
          icon: Icons.bolt,
          color: _autoColor,
          transactions: data.autoList,
          total: data.totalAuto,
          hiddenCount: data.hiddenAuto,
          maxVisible: maxVisible,
          showValidate: false,
          onChanged: onChanged,
        ),
        const SizedBox(height: 24),
        _SectionColumn(
          title: 'Factures manuelles',
          icon: Icons.description_outlined,
          color: _manualColor,
          transactions: data.manualList,
          total: data.totalManual,
          hiddenCount: data.hiddenManual,
          maxVisible: maxVisible,
          showValidate: true,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SectionColumn extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Transaction> transactions;
  final double total;
  final int hiddenCount;
  final int? maxVisible;
  final bool showValidate;
  final VoidCallback onChanged;

  const _SectionColumn({
    required this.title,
    required this.icon,
    required this.color,
    required this.transactions,
    required this.total,
    required this.hiddenCount,
    this.maxVisible,
    required this.showValidate,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final sortedTransactions = [...transactions]
      ..sort((a, b) => a.date.compareTo(b.date));
    final visibleTransactions = maxVisible == null
        ? sortedTransactions
        : sortedTransactions.take(maxVisible!).toList();
    final extraHidden = sortedTransactions.length - visibleTransactions.length;
    final totalHidden = hiddenCount + (extraHidden > 0 ? extraHidden : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            Text(
              AppFormats.currency.format(total),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (transactions.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Aucune echeance',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          ...visibleTransactions.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TransactionCard(
                transaction: t,
                color: color,
                showValidate: showValidate,
                onChanged: onChanged,
              ),
            ),
          ),
        if (totalHidden > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 2),
            child: Text(
              '+$totalHidden echeance${totalHidden > 1 ? 's' : ''} suivante${totalHidden > 1 ? 's' : ''} plus tard',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

class _TransactionCard extends ConsumerStatefulWidget {
  final Transaction transaction;
  final Color color;
  final bool showValidate;
  final VoidCallback onChanged;

  const _TransactionCard({
    required this.transaction,
    required this.color,
    required this.showValidate,
    required this.onChanged,
  });

  @override
  ConsumerState<_TransactionCard> createState() => _TransactionCardState();
}

class _TransactionCardState extends ConsumerState<_TransactionCard> {
  bool _loading = false;
  bool _isHovering = false;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _dueDateOnly {
    final date = widget.transaction.date;
    return DateTime(date.year, date.month, date.day);
  }

  bool get _isOverdue {
    return !widget.transaction.isAuto &&
        widget.transaction.isPending &&
        _dueDateOnly.isBefore(_today);
  }

  int get _overdueDays {
    return _today.difference(_dueDateOnly).inDays;
  }

  bool get _isPaid => widget.transaction.isCompleted;

  bool get _isDueToday =>
      widget.transaction.isPending && _dueDateOnly.isAtSameMomentAs(_today);

  int get _daysUntilDue {
    return _dueDateOnly.difference(_today).inDays;
  }

  String get _timingLabel {
    if (_isPaid) return 'Paye';
    if (_isOverdue) {
      return 'En retard de $_overdueDays jour${_overdueDays > 1 ? 's' : ''}';
    }
    if (_isDueToday) return 'Echeance aujourd\'hui';
    final days = _daysUntilDue;
    if (days < 0) {
      return widget.transaction.isAuto
          ? 'Prelevement auto deja passe'
          : 'Echeance depassee';
    }
    return 'Dans $days jour${days > 1 ? 's' : ''}';
  }

  Future<void> _validate() async {
    setState(() => _loading = true);
    try {
      final t = widget.transaction;
      final client = ref.read(apiClientProvider);
      await client.put(
        '/api/transactions/${t.id}',
        data: {
          'accountId': t.accountId,
          'date': DateFormat('yyyy-MM-dd').format(t.date),
          'amount': t.amount,
          'note': t.note,
          'status': 0,
          'isAuto': t.isAuto,
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
    final t = widget.transaction;
    final cardColor = _isOverdue ? _overdueColor : widget.color;
    final borderColor = _isHovering
        ? cardColor.withAlpha(120)
        : (_isOverdue ? _overdueColor.withAlpha(60) : const Color(0xFFD7DEE8));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _isHovering ? -2.0 : 0, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _isPaid
              ? const Color(0xFFF9FAFB)
              : (_isHovering ? const Color(0xFFF7FBF4) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: _isHovering ? 1.25 : 1.15,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0x14000000),
              blurRadius: _isHovering ? 16 : 10,
              offset: Offset(0, _isHovering ? 6 : 3),
            ),
          ],
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 104),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _isPaid
                      ? const Color(0xFFF3F4F6)
                      : cardColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isOverdue
                      ? Icons.warning_amber_rounded
                      : _getAccountIcon(t.accountName ?? ''),
                  color: _isPaid ? AppColors.textDisabled : cardColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.accountName ?? t.accountId,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _isPaid
                            ? AppColors.textDisabled
                            : AppColors.textPrimary,
                        decoration: _isPaid ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${DateFormat('dd MMM yyyy', 'fr_FR').format(t.date)} - $_timingLabel',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: _isOverdue
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: _isOverdue
                            ? _overdueColor
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppFormats.currency.format(t.amount),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _isPaid
                          ? AppColors.textDisabled
                          : _isOverdue
                          ? _overdueColor
                          : AppColors.textPrimary,
                    ),
                  ),
                  if (widget.showValidate && !_isPaid) ...[
                    const SizedBox(height: 8),
                    if (_loading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      SizedBox(
                        height: 30,
                        child: ElevatedButton(
                          onPressed: _validate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isOverdue
                                ? _overdueColor
                                : AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: Text(_isOverdue ? 'Payer' : 'Valider'),
                        ),
                      ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getAccountIcon(String name) {
    final lower = name.toLowerCase();
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

// -------------------------------------------------------------------------------
// CALENDAR VIEW
// -------------------------------------------------------------------------------
class _CalendarView extends ConsumerStatefulWidget {
  final _ScopedUpcomingData data;
  const _CalendarView({required this.data});

  @override
  ConsumerState<_CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<_CalendarView> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    final storedMonth = ref.read(_calendarMonthProvider);
    _currentMonth = DateTime(storedMonth.year, storedMonth.month);
  }

  List<Transaction> get _allTransactions => [
    ...widget.data.autoAll,
    ...widget.data.manualAll,
  ];

  int get _pendingCount => _allTransactions
      .where(
        (t) =>
            t.isPending &&
            t.date.year == _currentMonth.year &&
            t.date.month == _currentMonth.month,
      )
      .length;

  Future<void> _markAsPaid(Transaction transaction) async {
    final client = ref.read(apiClientProvider);
    await client.put(
      '/api/transactions/${transaction.id}',
      data: {
        'accountId': transaction.accountId,
        'date': DateFormat('yyyy-MM-dd').format(transaction.date),
        'amount': transaction.amount,
        'note': transaction.note,
        'status': 0,
        'isAuto': transaction.isAuto,
      },
    );
    invalidateAfterTransactionMutation(ref);
    ref.invalidate(upcomingTransactionsProvider);
  }

  Future<void> _updateTransaction({
    required Transaction transaction,
    required DateTime date,
    required double amount,
    required String? note,
  }) async {
    final client = ref.read(apiClientProvider);
    await client.put(
      '/api/transactions/${transaction.id}',
      data: {
        'accountId': transaction.accountId,
        'date': DateFormat('yyyy-MM-dd').format(date),
        'amount': amount,
        'note': note,
        'status': transaction.isCompleted ? 0 : 1,
        'isAuto': transaction.isAuto,
      },
    );
    invalidateAfterTransactionMutation(ref);
    ref.invalidate(upcomingTransactionsProvider);
  }

  Future<void> _openEditDialog(Transaction transaction) async {
    var selectedDate = DateTime(
      transaction.date.year,
      transaction.date.month,
      transaction.date.day,
    );
    final amountCtrl = TextEditingController(
      text: transaction.amount.toStringAsFixed(2).replaceAll('.', ','),
    );
    final noteCtrl = TextEditingController(text: transaction.note ?? '');
    var saving = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Modifier l\'echeance'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_month),
                    label: Text(
                      DateFormat('dd MMM yyyy', 'fr_FR').format(selectedDate),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Montant',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Note',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final parsed = double.tryParse(
                            amountCtrl.text.replaceAll(',', '.').trim(),
                          );
                          if (parsed == null || parsed <= 0) {
                            setDialogState(() => error = 'Montant invalide');
                            return;
                          }
                          setDialogState(() {
                            saving = true;
                            error = null;
                          });
                          try {
                            await _updateTransaction(
                              transaction: transaction,
                              date: selectedDate,
                              amount: parsed,
                              note: noteCtrl.text.trim().isEmpty
                                  ? null
                                  : noteCtrl.text.trim(),
                            );
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                          } catch (_) {
                            setDialogState(() {
                              saving = false;
                              error = 'Erreur de modification';
                            });
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openTransactionDetails(Transaction transaction) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final txDate = DateTime(
      transaction.date.year,
      transaction.date.month,
      transaction.date.day,
    );
    final isOverdue =
        !transaction.isAuto && transaction.isPending && txDate.isBefore(today);
    final isDueToday = transaction.isPending && txDate.isAtSameMomentAs(today);
    final dateLabel = DateFormat(
      'dd MMM yyyy',
      'fr_FR',
    ).format(transaction.date);
    String stateLabel;
    if (transaction.isCompleted) {
      stateLabel = 'Paye';
    } else if (isOverdue) {
      final days = today.difference(txDate).inDays;
      stateLabel = 'En retard de $days jour${days > 1 ? 's' : ''}';
    } else if (isDueToday) {
      stateLabel = 'Echeance aujourd\'hui';
    } else {
      final days = txDate.difference(today).inDays;
      if (days < 0) {
        stateLabel = transaction.isAuto
            ? 'Prelevement auto deja passe'
            : 'Echeance depassee';
      } else {
        stateLabel = 'Dans $days jour${days > 1 ? 's' : ''}';
      }
    }

    var loadingAction = false;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.accountName ?? transaction.accountId,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$dateLabel - $stateLabel',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isOverdue
                            ? _overdueColor
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppFormats.currency.format(transaction.amount),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if ((transaction.note ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        transaction.note!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (transaction.isPending && !transaction.isAuto) ...[
                          Expanded(
                            child: ElevatedButton(
                              onPressed: loadingAction
                                  ? null
                                  : () async {
                                      setSheetState(() => loadingAction = true);
                                      try {
                                        await _markAsPaid(transaction);
                                        if (!context.mounted) return;
                                        Navigator.of(context).pop();
                                      } finally {
                                        if (context.mounted) {
                                          setSheetState(
                                            () => loadingAction = false,
                                          );
                                        }
                                      }
                                    },
                              child: loadingAction
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Valider'),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: loadingAction
                                ? null
                                : () async {
                                    Navigator.of(context).pop();
                                    await _openEditDialog(transaction);
                                  },
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text('Modifier'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Month navigation
        _MonthNav(
          currentMonth: _currentMonth,
          pendingCount: _pendingCount,
          onPrev: () => setState(() {
            _currentMonth = DateTime(
              _currentMonth.year,
              _currentMonth.month - 1,
            );
            ref.read(_calendarMonthProvider.notifier).state = _currentMonth;
          }),
          onNext: () => setState(() {
            _currentMonth = DateTime(
              _currentMonth.year,
              _currentMonth.month + 1,
            );
            ref.read(_calendarMonthProvider.notifier).state = _currentMonth;
          }),
        ),
        const SizedBox(height: 16),
        const _CalendarLegend(),
        const SizedBox(height: 12),
        // Calendar grid
        _CalendarGrid(
          month: _currentMonth,
          transactions: _allTransactions,
          onTapTransaction: _openTransactionDetails,
        ),
      ],
    );
  }
}

class _MonthNav extends StatelessWidget {
  final DateTime currentMonth;
  final int pendingCount;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _MonthNav({
    required this.currentMonth,
    required this.pendingCount,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('MMMM yyyy', 'fr_FR').format(currentMonth);

    return Row(
      children: [
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
          splashRadius: 20,
        ),
        Text(
          label[0].toUpperCase() + label.substring(1),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          splashRadius: 20,
        ),
        const Spacer(),
        if (pendingCount > 0)
          Text(
            '$pendingCount facture${pendingCount > 1 ? 's' : ''} en attente',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
      ],
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDCE7D3)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: const [
          Text(
            'Legende calendrier:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          _LegendItem(label: 'Prelevement auto', color: _calendarAutoColor),
          _LegendItem(label: 'Facture manuelle', color: _calendarManualColor),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendItem({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime month;
  final List<Transaction> transactions;
  final ValueChanged<Transaction> onTapTransaction;

  const _CalendarGrid({
    required this.month,
    required this.transactions,
    required this.onTapTransaction,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstOfMonth = DateTime(month.year, month.month, 1);
    // Monday = 1, so offset is (weekday - 1)
    final startOffset = (firstOfMonth.weekday - 1) % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    const dayNames = [
      'LUNDI',
      'MARDI',
      'MERCREDI',
      'JEUDI',
      'VENDREDI',
      'SAMEDI',
      'DIMANCHE',
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD7DEE8), width: 1.15),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Day names header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
            ),
            child: Row(
              children: dayNames
                  .map(
                    (d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          // Rows
          for (int row = 0; row < rows; row++)
            Container(
              decoration: row < rows - 1
                  ? const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.borderSubtle),
                      ),
                    )
                  : null,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int col = 0; col < 7; col++)
                      _buildCell(row, col, startOffset, daysInMonth, today),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCell(
    int row,
    int col,
    int startOffset,
    int daysInMonth,
    DateTime today,
  ) {
    final cellIndex = row * 7 + col;
    final dayNum = cellIndex - startOffset + 1;
    final isCurrentMonth = dayNum >= 1 && dayNum <= daysInMonth;
    final cellDate = isCurrentMonth
        ? DateTime(month.year, month.month, dayNum)
        : null;
    final isToday =
        cellDate != null &&
        cellDate.year == today.year &&
        cellDate.month == today.month &&
        cellDate.day == today.day;

    // Get transactions for this day
    final dayTxns = isCurrentMonth
        ? transactions
              .where(
                (t) =>
                    t.date.year == cellDate!.year &&
                    t.date.month == cellDate.month &&
                    t.date.day == cellDate.day,
              )
              .toList()
        : <Transaction>[];

    // Calculate display day for prev/next month
    String displayDay = '';
    if (isCurrentMonth) {
      displayDay = '$dayNum';
    } else if (dayNum < 1) {
      final prevMonth = DateTime(month.year, month.month, 0);
      displayDay = '${prevMonth.day + dayNum}';
    } else {
      displayDay = '${dayNum - daysInMonth}';
    }

    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 120),
        decoration: BoxDecoration(
          color: isToday ? _calendarAccent.withAlpha(28) : null,
          borderRadius: isToday ? BorderRadius.circular(8) : null,
          border: col < 6
              ? const Border(right: BorderSide(color: AppColors.borderSubtle))
              : null,
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayDay,
              style: TextStyle(
                fontSize: isToday ? 16 : 13,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                color: isCurrentMonth
                    ? (isToday ? _calendarAccent : AppColors.textPrimary)
                    : AppColors.textDisabled.withAlpha(100),
              ),
            ),
            if (isToday)
              const Text(
                'AUJOURD\'HUI',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: _calendarAccent,
                  letterSpacing: 0.5,
                ),
              ),
            if (dayTxns.isNotEmpty) const SizedBox(height: 4),
            ...dayTxns.map(
              (t) =>
                  _EventChip(transaction: t, onTap: () => onTapTransaction(t)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventChip extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback onTap;
  const _EventChip({required this.transaction, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOverdue =
        !transaction.isAuto &&
        transaction.date.isBefore(DateTime.now()) &&
        transaction.isPending;
    final color = isOverdue
        ? _overdueColor
        : (transaction.isAuto ? _calendarAutoColor : _calendarManualColor);
    final tag = transaction.isAuto ? 'AUTO' : 'MANUEL';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color.withAlpha(24),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withAlpha(70)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '$tag ${(transaction.accountName ?? '').toUpperCase()}',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
