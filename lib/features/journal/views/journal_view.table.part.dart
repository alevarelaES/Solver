part of 'journal_view.dart';

class _JournalBody extends ConsumerWidget {
  final List<Transaction> transactions;
  final Transaction? selected;
  final bool isMobile;

  const _JournalBody({
    required this.transactions,
    required this.selected,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(_journalSortProvider);
    final pageItems = _sortJournalTransactions(transactions, sort);
    final showMonthHeaders = sort.column == _JournalSortColumn.date;
    final monthTotals = showMonthHeaders
        ? _buildMonthTotals(pageItems)
        : const <int, _MonthTotals>{};

    return Container(
      color: AppColors.surfaceElevated,
      child: Column(
        children: [
          Expanded(
            child: _TransactionTable(
              transactions: pageItems,
              monthTotals: monthTotals,
              showMonthHeaders: showMonthHeaders,
              isMobile: isMobile,
              onSelect: (tx) => _onSelect(context, ref, tx, isMobile),
              selectedId: selected?.id,
            ),
          ),
        ],
      ),
    );
  }

  void _onSelect(
    BuildContext context,
    WidgetRef ref,
    Transaction tx,
    bool isMobile,
  ) {
    ref.read(_selectedTxIdProvider.notifier).state = tx.id;
    if (!isMobile) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.86,
        minChildSize: 0.55,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.xxl),
            ),
          ),
          child: SingleChildScrollView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(AppSpacing.s14, AppSpacing.md, AppSpacing.s14, AppSpacing.xxl),
            child: _DetailView(
              transaction: tx,
              onClose: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
    );
  }
}

Map<int, _MonthTotals> _buildMonthTotals(List<Transaction> transactions) {
  final map = <int, _MonthTotals>{};
  for (final tx in transactions) {
    final key = _monthKey(tx.date);
    final current = map[key] ?? const _MonthTotals();
    if (tx.isIncome) {
      map[key] = current.copyWith(income: current.income + tx.amount.abs());
    } else {
      map[key] = current.copyWith(expense: current.expense + tx.amount.abs());
    }
  }
  return map;
}

int _monthKey(DateTime date) => date.year * 100 + date.month;

class _MonthTotals {
  final double income;
  final double expense;

  const _MonthTotals({this.income = 0, this.expense = 0});

  _MonthTotals copyWith({double? income, double? expense}) => _MonthTotals(
    income: income ?? this.income,
    expense: expense ?? this.expense,
  );
}

class _DesktopDetailOverlay extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback onClose;

  const _DesktopDetailOverlay({
    required this.transaction,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final width = math.min(620.0, MediaQuery.sizeOf(context).width * 0.46);
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            onTap: onClose,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2.8, sigmaY: 2.8),
              child: Container(color: Colors.black.withAlpha(70)),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 1, end: 0),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Transform.translate(
                offset: Offset(80 * value, 0),
                child: Opacity(opacity: 1 - value * 0.25, child: child),
              ),
              child: Container(
                width: width,
                height: double.infinity,
                padding: const EdgeInsets.fromLTRB(AppSpacing.s14, AppSpacing.s14, AppSpacing.s14, AppSpacing.s14),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceElevated,
                  border: Border(
                    left: BorderSide(color: AppColors.borderSubtle),
                  ),
                ),
                child: SingleChildScrollView(
                  child: _DetailView(
                    transaction: transaction,
                    onClose: onClose,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTable extends StatelessWidget {
  final List<Transaction> transactions;
  final Map<int, _MonthTotals> monthTotals;
  final bool showMonthHeaders;
  final bool isMobile;
  final String? selectedId;
  final ValueChanged<Transaction> onSelect;

  const _TransactionTable({
    required this.transactions,
    required this.monthTotals,
    required this.showMonthHeaders,
    required this.isMobile,
    required this.onSelect,
    required this.selectedId,
  });

  @override
  Widget build(BuildContext context) {
    final rows = _buildRows(transactions, showMonthHeaders);
    return AppPanel(
      padding: EdgeInsets.zero,
      radius: AppRadius.md,
      variant: AppPanelVariant.surface,
      backgroundColor: AppColors.surfaceCard,
      borderColor: AppColors.borderTable,
      boxShadow: AppShadows.cardHover,
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          _JournalFilterBar(isMobile: isMobile),
          _TableHeader(isMobile: isMobile),
          const Divider(height: 1, color: AppColors.borderTable),
          Expanded(
            child: rows.isEmpty
                ? const Center(
                    child: Text(
                      'Aucune transaction sur ce filtre',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final entry = rows[index];
                      if (entry.monthHeader != null) {
                        final key = _monthKey(entry.monthHeader!);
                        return _MonthHeaderRow(
                          monthDate: entry.monthHeader!,
                          totals: monthTotals[key] ?? const _MonthTotals(),
                          isMobile: isMobile,
                        );
                      }
                      final tx = entry.transaction!;
                      return _TransactionRow(
                        transaction: tx,
                        isMobile: isMobile,
                        selected: tx.id == selectedId,
                        isEven: index % 2 == 0,
                        onTap: () => onSelect(tx),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<_TableRowEntry> _buildRows(
    List<Transaction> txs,
    bool withMonthHeaders,
  ) {
    if (!withMonthHeaders) {
      return txs.map(_TableRowEntry.transaction).toList(growable: false);
    }
    final rows = <_TableRowEntry>[];
    int? month;
    int? year;
    for (final tx in txs) {
      if (tx.date.month != month || tx.date.year != year) {
        month = tx.date.month;
        year = tx.date.year;
        rows.add(_TableRowEntry.month(tx.date));
      }
      rows.add(_TableRowEntry.transaction(tx));
    }
    return rows;
  }
}

class _TableRowEntry {
  final DateTime? monthHeader;
  final Transaction? transaction;

  const _TableRowEntry.month(DateTime month)
    : monthHeader = month,
      transaction = null;

  const _TableRowEntry.transaction(Transaction tx)
    : monthHeader = null,
      transaction = tx;
}

class _MonthHeaderRow extends StatelessWidget {
  final DateTime monthDate;
  final _MonthTotals totals;
  final bool isMobile;

  const _MonthHeaderRow({
    required this.monthDate,
    required this.totals,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy', 'fr_FR').format(monthDate);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSuccessHeader,
        border: const Border(
          top: BorderSide(color: AppColors.borderSuccessSoft),
          bottom: BorderSide(color: AppColors.borderSuccessSoft),
        ),
      ),
      child: Row(
        children: [
          Text(
            monthLabel[0].toUpperCase() + monthLabel.substring(1),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
              letterSpacing: 0.4,
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Gagne ${AppFormats.currency.format(totals.income)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Depense ${AppFormats.currency.format(totals.expense)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends ConsumerWidget {
  final bool isMobile;
  const _TableHeader({required this.isMobile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(_journalSortProvider);
    const style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      color: AppColors.textPrimary,
      letterSpacing: 0.9,
    );
    final headerDecoration = BoxDecoration(
      color: AppColors.surfaceHeaderAlt,
      border: const Border(bottom: BorderSide(color: AppColors.borderTable)),
    );
    if (isMobile) {
      return Container(
        decoration: headerDecoration,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: _SortableHeaderLabel(
                  label: 'TRANSACTION',
                  style: style,
                  active: sort.column == _JournalSortColumn.date,
                  ascending: sort.ascending,
                  onTap: () => _toggleSort(ref, _JournalSortColumn.date),
                ),
              ),
              Expanded(
                flex: 2,
                child: _SortableHeaderLabel(
                  label: 'MONTANT',
                  style: style,
                  active: sort.column == _JournalSortColumn.amount,
                  ascending: sort.ascending,
                  alignEnd: true,
                  onTap: () => _toggleSort(ref, _JournalSortColumn.amount),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: headerDecoration,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: _SortableHeaderLabel(
                label: 'DATE',
                style: style,
                active: sort.column == _JournalSortColumn.date,
                ascending: sort.ascending,
                onTap: () => _toggleSort(ref, _JournalSortColumn.date),
              ),
            ),
            Expanded(
              flex: 4,
              child: _SortableHeaderLabel(
                label: 'LIBELLE',
                style: style,
                active: sort.column == _JournalSortColumn.label,
                ascending: sort.ascending,
                onTap: () => _toggleSort(ref, _JournalSortColumn.label),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'GROUPE',
                style: style.copyWith(
                  color: AppColors.textPrimary.withAlpha(180),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                'DESCRIPTION',
                style: style.copyWith(
                  color: AppColors.textPrimary.withAlpha(180),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: _SortableHeaderLabel(
                label: 'MONTANT',
                style: style,
                active: sort.column == _JournalSortColumn.amount,
                ascending: sort.ascending,
                alignEnd: true,
                onTap: () => _toggleSort(ref, _JournalSortColumn.amount),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleSort(WidgetRef ref, _JournalSortColumn column) {
    final current = ref.read(_journalSortProvider);
    if (current.column == column) {
      ref.read(_journalSortProvider.notifier).state = current.copyWith(
        ascending: !current.ascending,
      );
      return;
    }

    final defaultAscending = column == _JournalSortColumn.date ? false : true;
    ref.read(_journalSortProvider.notifier).state = _JournalSortState(
      column: column,
      ascending: defaultAscending,
    );
  }
}

class _SortableHeaderLabel extends StatelessWidget {
  final String label;
  final TextStyle style;
  final bool active;
  final bool ascending;
  final bool alignEnd;
  final VoidCallback onTap;

  const _SortableHeaderLabel({
    required this.label,
    required this.style,
    required this.active,
    required this.ascending,
    required this.onTap,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    final icon = active
        ? (ascending ? Icons.arrow_upward : Icons.arrow_downward)
        : Icons.unfold_more;
    final color = active
        ? AppColors.textPrimary
        : AppColors.textPrimary.withAlpha(170);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: alignEnd
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Text(
              label,
              style: style.copyWith(color: color),
              textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            ),
            const SizedBox(width: 4),
            Icon(icon, size: 13, color: color),
          ],
        ),
      ),
    );
  }
}

class _TransactionRow extends StatefulWidget {
  final Transaction transaction;
  final bool isMobile;
  final bool selected;
  final bool isEven;
  final VoidCallback onTap;

  const _TransactionRow({
    required this.transaction,
    required this.isMobile,
    required this.selected,
    this.isEven = false,
    required this.onTap,
  });

  @override
  State<_TransactionRow> createState() => _TransactionRowState();
}

class _TransactionRowState extends State<_TransactionRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final transaction = widget.transaction;
    final amountPrefix = transaction.isIncome ? '+' : '-';
    final amountColor = transaction.isIncome
        ? AppColors.primary
        : AppColors.danger;
    final groupLabel = _transactionGroup(transaction);
    final description = _transactionDescription(transaction);
    final baseBg = widget.isMobile
        ? Colors.transparent
        : (widget.isEven ? Colors.white : AppColors.surfaceTableRowStripe);
    final rowBg = widget.selected
        ? AppColors.primary.withAlpha(_hovered ? 52 : 34)
        : _hovered
        ? (transaction.isIncome
              ? AppColors.primary.withAlpha(24)
              : AppColors.danger.withAlpha(22))
        : baseBg;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: rowBg,
            border: const Border(
              bottom: BorderSide(color: AppColors.borderTableRow),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: widget.isMobile
              ? Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Row(
                        children: [
                          _TransactionAvatar(
                            transaction: transaction,
                            size: 30,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _displayLabel(transaction),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat(
                                    'dd MMM yyyy',
                                    'fr_FR',
                                  ).format(transaction.date),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '$amountPrefix${AppFormats.currency.format(transaction.amount)}',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: amountColor,
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        DateFormat(
                          'dd MMM yyyy',
                          'fr_FR',
                        ).format(transaction.date),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Row(
                        children: [
                          _TransactionAvatar(
                            transaction: transaction,
                            size: 32,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _displayLabel(transaction),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (!transaction.isCompleted) ...[
                                  const SizedBox(height: 4),
                                  _StatusPill(transaction: transaction),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _TransactionGroupTag(label: groupLabel),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: description == null
                          ? Text(
                              '-',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary.withAlpha(120),
                              ),
                            )
                          : _FadedInlineText(
                              text: description,
                              fadeColor: rowBg,
                            ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '$amountPrefix${AppFormats.currency.format(transaction.amount)}',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: amountColor,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

