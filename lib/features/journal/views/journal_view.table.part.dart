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

    return Column(
      children: [
        if (!isMobile) JournalKpiBanner(transactions: transactions),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.sm,
            ),
            child: _TransactionTable(
              transactions: pageItems,
              monthTotals: monthTotals,
              showMonthHeaders: showMonthHeaders,
              isMobile: isMobile,
              onSelect: (tx) => _onSelect(context, ref, tx, isMobile),
              selectedId: selected?.id,
            ),
          ),
        ),
      ],
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
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s14,
              AppSpacing.md,
              AppSpacing.s14,
              AppSpacing.xxl,
            ),
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
    if (tx.isVoided) continue;
    final key = _monthKey(tx.date);
    final current = map[key] ?? const _MonthTotals();
    // Reversal of expense = negative amount on expense account = money coming back = income
    final isEffectivelyIncome = tx.isIncome || (!tx.isIncome && tx.amount < 0);
    if (isEffectivelyIncome) {
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
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s14,
                  AppSpacing.s14,
                  AppSpacing.s14,
                  AppSpacing.s14,
                ),
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
    // PremiumCardBase gives the glassmorphic surface — ClipRRect ensures
    // child content is clipped to the rounded corners.
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: PremiumCardBase(
        variant: PremiumCardVariant.standard,
        padding: EdgeInsets.zero,
        borderRadius: AppRadius.md,
        child: Column(
          children: [
            _JournalFilterBar(isMobile: isMobile),
            _TableHeader(isMobile: isMobile),
            const Divider(height: 1, color: AppColors.borderTable),
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Text(
                        AppStrings.journal.noTransactionsFilter,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                      itemCount: rows.length,
                      separatorBuilder: (context, index) {
                        // N'afficher un séparateur que si le suivant ou le précédent n'est pas un Header de mois
                        if (rows[index].monthHeader != null ||
                            (index + 1 < rows.length &&
                                rows[index + 1].monthHeader != null)) {
                          return const SizedBox.shrink();
                        }
                        return const Divider(
                          height: 1,
                          color: AppColors.borderSubtle,
                          indent: 14,
                          endIndent: 14,
                        );
                      },
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
                          onTap: () => onSelect(tx),
                        );
                      },
                    ),
            ),
          ],
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16, bottom: 4),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceElevated.withAlpha(150) : AppColors.surfaceMuted,
        border: const Border.symmetric(
          horizontal: BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      child: Row(
        children: [
            Text(
              monthLabel[0].toUpperCase() + monthLabel.substring(1),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                letterSpacing: 0.3,
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
                      AppStrings.journal.earned(
                        AppFormats.formatFromChf(totals.income),
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      AppStrings.journal.spent(
                        AppFormats.formatFromChf(totals.expense),
                      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      color: headerColor,
      letterSpacing: 0.9,
    );
    final headerDecoration = BoxDecoration(
      color: isDark ? AppColors.surfaceElevated : AppColors.surfaceLight,
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
                  label: AppStrings.journal.colTransaction,
                  style: style,
                  active: sort.column == _JournalSortColumn.date,
                  ascending: sort.ascending,
                  onTap: () => _toggleSort(ref, _JournalSortColumn.date),
                ),
              ),
              Expanded(
                flex: 2,
                child: _SortableHeaderLabel(
                  label: AppStrings.journal.colAmount,
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
                label: AppStrings.journal.colDate,
                style: style,
                active: sort.column == _JournalSortColumn.date,
                ascending: sort.ascending,
                onTap: () => _toggleSort(ref, _JournalSortColumn.date),
              ),
            ),
            Expanded(
              flex: 5,
              child: _SortableHeaderLabel(
                label: AppStrings.journal.colLabel,
                style: style,
                active: sort.column == _JournalSortColumn.label,
                ascending: sort.ascending,
                onTap: () => _toggleSort(ref, _JournalSortColumn.label),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                AppStrings.journal.colGroup,
                style: style.copyWith(color: headerColor.withAlpha(180)),
              ),
            ),
            Expanded(
              flex: 2,
              child: _SortableHeaderLabel(
                label: AppStrings.journal.colAmount,
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
    final baseColor = style.color ?? AppColors.textSecondary;
    final color = active ? baseColor : baseColor.withAlpha(160);

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
  final VoidCallback onTap;

  const _TransactionRow({
    required this.transaction,
    required this.isMobile,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_TransactionRow> createState() => _TransactionRowState();
}

class _TransactionRowState extends State<_TransactionRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final transaction = widget.transaction;
    final signedAmount = transaction.signedAmount;
    final amountPrefix = signedAmount >= 0 ? '+' : '-';
    final amountColor = signedAmount >= 0 ? AppColors.primary : AppColors.danger;
    final groupLabel = _transactionGroup(transaction);
    final isVoided = transaction.isVoided;
    final hoverColor = isDark ? AppColors.surfaceMuted : AppColors.primary;
    final baseBg = hoverColor.withAlpha(0);
    final rowBg = widget.selected
        ? AppColors.primary.withAlpha(isDark ? 40 : 20)
        : _hovered
        ? hoverColor.withAlpha(isDark ? 80 : 12)
        : baseBg;

    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final accountSubtitle = (transaction.accountName ?? '').trim();
    final showAccountSubtitle = accountSubtitle.isNotEmpty &&
        accountSubtitle != _displayLabel(transaction);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: rowBg,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                    decoration: isVoided
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat('dd MMM yyyy', 'fr_FR')
                                      .format(transaction.date),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textSecondary,
                                    decoration: isVoided
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
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
                        '$amountPrefix${AppFormats.formatFromChf(signedAmount.abs())}',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: amountColor,
                          decoration: isVoided
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
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
                        DateFormat('dd MMM yyyy', 'fr_FR').format(transaction.date),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                          decoration: isVoided
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: Row(
                        children: [
                          _TransactionAvatar(
                            transaction: transaction,
                            size: 32,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _displayLabel(transaction),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                    decoration: isVoided
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                  ),
                                ),
                                if (showAccountSubtitle) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    accountSubtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: textSecondary,
                                      fontWeight: FontWeight.w500,
                                      decoration: isVoided
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                    ),
                                  ),
                                ],
                                if (isVoided) ...[
                                  const SizedBox(height: 4),
                                  _StatusBadge(
                                    label: AppStrings.journal.statusVoided,
                                    color: AppColors.textDisabled,
                                  ),
                                ] else if (!transaction.isCompleted) ...[
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
                      flex: 2,
                      child: Text(
                        '$amountPrefix${AppFormats.formatFromChf(signedAmount.abs())}',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: amountColor,
                          decoration: isVoided
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
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

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(AppRadius.r7),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// _JournalKpiStrip and _KpiCell removed — replaced by JournalKpiBanner widget.
