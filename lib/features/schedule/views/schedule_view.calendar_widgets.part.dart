part of 'schedule_view.dart';

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceSuccessSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderSuccess),
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
        border: Border.all(color: AppColors.borderStrong, width: 1.15),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowOverlaySm,
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
          borderRadius: isToday ? BorderRadius.circular(AppRadius.r10) : null,
          border: col < 6
              ? const Border(right: BorderSide(color: AppColors.borderSubtle))
              : null,
        ),
        padding: const EdgeInsets.all(AppSpacing.s6),
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
      borderRadius: BorderRadius.circular(AppRadius.r6),
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color.withAlpha(24),
          borderRadius: BorderRadius.circular(AppRadius.r6),
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
