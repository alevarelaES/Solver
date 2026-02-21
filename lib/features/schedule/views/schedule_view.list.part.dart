part of 'schedule_view.dart';

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
              title: AppStrings.schedule.sectionAuto,
              icon: Icons.bolt,
              color: _autoColor,
              transactions: data.autoList,
              visibleTotal: data.visibleTotalAuto,
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
              title: AppStrings.schedule.sectionManual,
              icon: Icons.description_outlined,
              color: _manualColor,
              transactions: data.manualList,
              visibleTotal: data.visibleTotalManual,
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
          visibleTotal: data.visibleTotalAuto,
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
          visibleTotal: data.visibleTotalManual,
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
  final double visibleTotal;
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
    required this.visibleTotal,
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
    final showReferenceTotal = (total - visibleTotal).abs() > 0.009;

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
            if (transactions.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  '${transactions.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
            const Spacer(),
            if (!showReferenceTotal)
              Text(
                AppFormats.formatFromChf(total),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppFormats.formatFromChf(visibleTotal),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '(${AppFormats.formatFromChf(total)})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (transactions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.xxl,
              horizontal: AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: color.withValues(alpha: 0.12)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 36,
                  color: color.withValues(alpha: 0.35),
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.schedule.noDeadlines,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Tout est à jour !',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDisabled,
                  ),
                ),
              ],
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
