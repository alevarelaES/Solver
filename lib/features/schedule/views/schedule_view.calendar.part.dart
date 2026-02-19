part of 'schedule_view.dart';

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
