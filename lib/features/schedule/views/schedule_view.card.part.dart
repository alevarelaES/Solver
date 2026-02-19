part of 'schedule_view.dart';

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
    final noteText = (t.note ?? '').trim();
    final hasNote = noteText.isNotEmpty;
    final cardColor = _isOverdue ? _overdueColor : widget.color;
    final borderColor = _isHovering
        ? cardColor.withAlpha(120)
        : (_isOverdue ? _overdueColor.withAlpha(60) : AppColors.borderStrong);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _isHovering ? -2.0 : 0, 0),
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: _isPaid
              ? AppColors.surfaceElevated
              : (_isHovering ? AppColors.surfaceSuccess : Colors.white),
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          border: Border.all(
            color: borderColor,
            width: _isHovering ? 1.25 : 1.15,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowOverlayMd,
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
                      ? AppColors.surfaceHeader
                      : cardColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
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
                    if (hasNote) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.sticky_note_2_outlined,
                            size: 12,
                            color: _isPaid
                                ? AppColors.textDisabled
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              noteText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: _isPaid
                                    ? AppColors.textDisabled
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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
                          style:
                              AppButtonStyles.primary(
                                backgroundColor: _isOverdue
                                    ? _overdueColor
                                    : AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                radius: AppRadius.r10,
                              ).copyWith(
                                textStyle: const WidgetStatePropertyAll(
                                  TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
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
