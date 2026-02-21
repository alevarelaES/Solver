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

  // Urgency-based color hierarchy: overdue → red, ≤7j → amber, else → section color
  Color get _urgencyColor {
    if (_isOverdue) return _overdueColor;
    final days = _daysUntilDue;
    if (days >= 0 && days <= 7) return AppColors.warning;
    return widget.color;
  }

  String get _timingLabel {
    if (_isPaid) return 'Payé';
    if (_isOverdue) {
      return 'En retard de $_overdueDays jour${_overdueDays > 1 ? 's' : ''}';
    }
    if (_isDueToday) return 'Échéance aujourd\'hui';
    final days = _daysUntilDue;
    if (days < 0) {
      return widget.transaction.isAuto
          ? 'Prélèvement auto déjà passé'
          : 'Échéance dépassée';
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
          'date': DateFormat('yyyy-MM-dd').format(
            t.isAuto ? t.date : DateTime.now(),
          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = widget.transaction;
    final noteText = (t.note ?? '').trim();
    final hasNote = noteText.isNotEmpty;
    final cardColor = _urgencyColor;
    final isUrgent = !_isPaid &&
        (_isOverdue ||
            _isDueToday ||
            (_daysUntilDue >= 0 && _daysUntilDue <= 7));

    // Background tint: subtle red on overdue, hover tint otherwise
    final Color cardBg;
    if (_isPaid) {
      cardBg = isDark ? AppColors.surfaceElevated : AppColors.surfaceElevated;
    } else if (_isHovering) {
      cardBg = cardColor.withValues(alpha: 0.07);
    } else if (_isOverdue) {
      cardBg = _overdueColor.withValues(alpha: 0.03);
    } else {
      cardBg = isDark ? const Color(0xFF1A2616) : Colors.white;
    }

    // Border: colored on urgent, standard otherwise
    final borderColor = _isHovering
        ? cardColor.withValues(alpha: 0.45)
        : isUrgent
        ? cardColor.withValues(alpha: 0.22)
        : (isDark ? AppColors.borderDark : AppColors.borderStrong);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _isHovering ? -2.0 : 0, 0),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          border: Border.all(
            color: borderColor,
            width: _isHovering ? 1.25 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowOverlayMd,
              blurRadius: _isHovering ? 16 : 10,
              offset: Offset(0, _isHovering ? 6 : 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xxl - 1),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Left accent bar ──────────────────────────────────────
                if (!_isPaid)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 170),
                    width: 4,
                    color: cardColor,
                  ),
                // ── Main content ─────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Row(
                      children: [
                        // Icon badge
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _isPaid
                                ? AppColors.surfaceHeader
                                : cardColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                          child: Icon(
                            _isOverdue
                                ? Icons.schedule_rounded
                                : _getAccountIcon(t.accountName ?? ''),
                            color: _isPaid ? AppColors.textDisabled : cardColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Title + timing + note
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
                                      : isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight,
                                  decoration: _isPaid
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${DateFormat('dd MMM yyyy', 'fr_FR').format(t.date)} · $_timingLabel',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isUrgent
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isUrgent
                                      ? cardColor
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
                        // Amount + action button
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              AppFormats.formatFromChf(t.amount),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _isPaid
                                    ? AppColors.textDisabled
                                    : _isOverdue
                                    ? cardColor
                                    : isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                            if (widget.showValidate && !_isPaid) ...[
                              const SizedBox(height: 8),
                              if (_loading)
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: cardColor,
                                  ),
                                )
                              else
                                SizedBox(
                                  height: 30,
                                  child: FilledButton.tonal(
                                    onPressed: _validate,
                                    style: ButtonStyle(
                                      backgroundColor: WidgetStatePropertyAll(
                                        cardColor.withValues(alpha: 0.12),
                                      ),
                                      foregroundColor:
                                          WidgetStatePropertyAll(cardColor),
                                      overlayColor: WidgetStatePropertyAll(
                                        cardColor.withValues(alpha: 0.08),
                                      ),
                                      side: WidgetStatePropertyAll(
                                        BorderSide(
                                          color: cardColor.withValues(
                                            alpha: 0.30,
                                          ),
                                          width: 1,
                                        ),
                                      ),
                                      padding: const WidgetStatePropertyAll(
                                        EdgeInsets.symmetric(horizontal: 14),
                                      ),
                                      minimumSize: const WidgetStatePropertyAll(
                                        Size(0, 30),
                                      ),
                                      shape: WidgetStatePropertyAll(
                                        RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.r10,
                                          ),
                                        ),
                                      ),
                                      textStyle: const WidgetStatePropertyAll(
                                        TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      elevation: const WidgetStatePropertyAll(0),
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
