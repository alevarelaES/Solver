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

// -- Colours -----------------------------------------------------------------
const _autoColor = AppColors.primary;
const _manualColor = Color(0xFFF97316); // orange
const _overdueColor = AppColors.danger;

class ScheduleView extends ConsumerWidget {
  const ScheduleView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcomingAsync = ref.watch(upcomingTransactionsProvider);

    return upcomingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Erreur: $e',
          style: const TextStyle(color: AppColors.danger),
        ),
      ),
      data: (data) => LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1440),
                child: Column(
                  children: [
                    _HeroHeader(data: data),
                    const SizedBox(height: 24),
                    _Body(data: data, maxWidth: constraints.maxWidth),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// -------------------------------------------------------------------------------
// HERO HEADER
// -------------------------------------------------------------------------------
class _HeroHeader extends ConsumerWidget {
  final UpcomingData data;
  const _HeroHeader({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCalendar = ref.watch(_calendarModeProvider);
    final isDesktop = MediaQuery.sizeOf(context).width >= 980;
    final now = DateTime.now();
    final monthLabel = DateFormat(
      'MMMM yyyy',
      'fr_FR',
    ).format(now).toUpperCase();

    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TOTAL A PAYER · $monthLabel',
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
        Wrap(
          spacing: 24,
          runSpacing: 6,
          children: [
            _DotLabel(
              label: 'Prélèvements Auto:',
              amount: AppFormats.currency.format(data.totalAuto),
              color: _autoColor,
            ),
            _DotLabel(
              label: 'Factures Manuelles:',
              amount: AppFormats.currency.format(data.totalManual),
              color: _manualColor,
            ),
          ],
        ),
      ],
    );

    final modeToggle = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleChip(
            label: 'Liste',
            isActive: !isCalendar,
            onTap: () => ref.read(_calendarModeProvider.notifier).state = false,
          ),
          _ToggleChip(
            label: 'Calendrier',
            isActive: isCalendar,
            onTap: () => ref.read(_calendarModeProvider.notifier).state = true,
          ),
        ],
      ),
    );

    if (!isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          summary,
          const SizedBox(height: 16),
          Align(alignment: Alignment.centerRight, child: modeToggle),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: summary),
        const SizedBox(width: 16),
        modeToggle,
      ],
    );
  }
}

class _DotLabel extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;
  const _DotLabel({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          amount,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
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
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isActive ? AppColors.primary : AppColors.textDisabled,
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
  final UpcomingData data;
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
  final UpcomingData data;
  final double maxWidth;
  const _ListViewBody({required this.data, required this.maxWidth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = maxWidth > 960;
    void onChanged() => ref.invalidate(upcomingTransactionsProvider);

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _SectionColumn(
              title: 'Prélèvements Auto',
              icon: Icons.bolt,
              color: _autoColor,
              transactions: data.auto,
              total: data.totalAuto,
              showValidate: false,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: _SectionColumn(
              title: 'Factures Manuelles',
              icon: Icons.description_outlined,
              color: _manualColor,
              transactions: data.manual,
              total: data.totalManual,
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
          title: 'Prélèvements Auto',
          icon: Icons.bolt,
          color: _autoColor,
          transactions: data.auto,
          total: data.totalAuto,
          showValidate: false,
          onChanged: onChanged,
        ),
        const SizedBox(height: 24),
        _SectionColumn(
          title: 'Factures Manuelles',
          icon: Icons.description_outlined,
          color: _manualColor,
          transactions: data.manual,
          total: data.totalManual,
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
  final bool showValidate;
  final VoidCallback onChanged;

  const _SectionColumn({
    required this.title,
    required this.icon,
    required this.color,
    required this.transactions,
    required this.total,
    required this.showValidate,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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
                fontSize: 14,
              ),
            ),
            const Spacer(),
            Text(
              AppFormats.currency.format(total),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (transactions.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Aucune échéance',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          ...([...transactions]..sort((a, b) => a.date.compareTo(b.date))).map(
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

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _dueDateOnly {
    final date = widget.transaction.date;
    return DateTime(date.year, date.month, date.day);
  }

  bool get _isOverdue {
    return widget.transaction.isPending && _dueDateOnly.isBefore(_today);
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
    if (_isPaid) return 'Payé';
    if (_isOverdue) {
      return 'En retard de $_overdueDays jour${_overdueDays > 1 ? 's' : ''}';
    }
    if (_isDueToday) return 'Échéance aujourd\'hui';
    final days = _daysUntilDue;
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isPaid ? const Color(0xFFF9FAFB) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isOverdue
              ? _overdueColor.withAlpha(60)
              : AppColors.borderSubtle,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 104),
        child: Row(
          children: [
            // Icon
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
            // Name + date
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
                    '${DateFormat('dd MMM yyyy', 'fr_FR').format(t.date)} · $_timingLabel',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: _isOverdue
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: _isOverdue
                          ? _overdueColor
                          : AppColors.textDisabled,
                    ),
                  ),
                ],
              ),
            ),
            // Amount + validate button
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
  final UpcomingData data;
  const _CalendarView({required this.data});

  @override
  ConsumerState<_CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<_CalendarView> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  List<Transaction> get _allTransactions => [
    ...widget.data.auto,
    ...widget.data.manual,
  ];

  int get _pendingCount => _allTransactions.where((t) => t.isPending).length;

  Future<void> _openTransactionDetails(Transaction transaction) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final txDate = DateTime(
      transaction.date.year,
      transaction.date.month,
      transaction.date.day,
    );
    final isOverdue = transaction.isPending && txDate.isBefore(today);
    final isDueToday = transaction.isPending && txDate.isAtSameMomentAs(today);
    final dateLabel = DateFormat(
      'dd MMM yyyy',
      'fr_FR',
    ).format(transaction.date);
    String stateLabel;
    if (transaction.isCompleted) {
      stateLabel = 'Payé';
    } else if (isOverdue) {
      final days = today.difference(txDate).inDays;
      stateLabel = 'En retard de $days jour${days > 1 ? 's' : ''}';
    } else if (isDueToday) {
      stateLabel = 'Échéance aujourd\'hui';
    } else {
      final days = txDate.difference(today).inDays;
      stateLabel = 'Dans $days jour${days > 1 ? 's' : ''}';
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
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
                  '$dateLabel · $stateLabel',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isOverdue ? _overdueColor : AppColors.textSecondary,
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
              ],
            ),
          ),
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
          }),
          onNext: () => setState(() {
            _currentMonth = DateTime(
              _currentMonth.year,
              _currentMonth.month + 1,
            );
          }),
        ),
        const SizedBox(height: 16),
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
              color: AppColors.textDisabled,
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
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(16),
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
                            color: AppColors.textDisabled,
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
          color: isToday ? AppColors.primary.withAlpha(12) : null,
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
                    ? (isToday ? AppColors.primary : AppColors.textPrimary)
                    : AppColors.textDisabled.withAlpha(100),
              ),
            ),
            if (isToday)
              const Text(
                'AUJOURD\'HUI',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
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
        transaction.date.isBefore(DateTime.now()) && transaction.isPending;
    final color = isOverdue
        ? _overdueColor
        : (transaction.isAuto ? _autoColor : _manualColor);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withAlpha(40)),
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
                (transaction.accountName ?? '').toUpperCase(),
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
