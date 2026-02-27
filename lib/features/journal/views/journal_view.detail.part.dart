part of 'journal_view.dart';

class _DetailView extends ConsumerStatefulWidget {
  final Transaction transaction;
  final VoidCallback? onClose;

  const _DetailView({required this.transaction, this.onClose});

  @override
  ConsumerState<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends ConsumerState<_DetailView> {
  bool _loading = false;

  Future<void> _validate({double? overrideAmount}) async {
    setState(() => _loading = true);
    try {
      final client = ref.read(apiClientProvider);
      final tx = widget.transaction;
      await client.put(
        '/api/transactions/${tx.id}',
        data: {
          'accountId': tx.accountId,
          'date': DateFormat('yyyy-MM-dd').format(tx.date),
          'amount': overrideAmount ?? tx.amount,
          'note': tx.note,
          'status': 0,
          'isAuto': tx.isAuto,
        },
      );
      _afterMutation();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reverseTransaction({String? reason, double? amount}) async {
    setState(() => _loading = true);
    try {
      final tx = widget.transaction;
      await ref
          .read(apiClientProvider)
          .post(
            '/api/transactions/${tx.id}/reverse',
            data: {
              if (reason != null && reason.trim().isNotEmpty)
                'reason': reason.trim(),
              'amount': ?amount,
            },
          );
      _afterMutation();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction annulee avec contre-ecriture.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de l annulation.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _afterMutation() {
    if (!mounted) return;
    invalidateAfterTransactionMutation(ref);
  }

  void _showValidateDialog() {
    final ctrl = TextEditingController(
      text: widget.transaction.amount.toStringAsFixed(2),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          AppStrings.journal.markAsPaid,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: AppStrings.journal.amountLabelCode(
              AppFormats.currencyCode,
            ),
            prefixText: '${AppFormats.currencySymbol} ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              AppStrings.common.cancel,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final amount = double.tryParse(ctrl.text.replaceAll(',', '.'));
              _validate(overrideAmount: amount);
            },
            child: Text(AppStrings.journal.confirmAction),
          ),
        ],
      ),
    );
  }

  void _showReverseDialog() {
    final tx = widget.transaction;
    final reasonCtrl = TextEditingController();
    final amountCtrl = TextEditingController(
      text: tx.amount.abs().toStringAsFixed(2),
    );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text(
          'Annuler et rembourser',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Montant remboursé (max ${tx.amount.abs().toStringAsFixed(2)})',
                prefixText: '${AppFormats.currencySymbol} ',
                helperText: 'Laisser le montant total pour annulation complète',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLength: 250,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Raison (optionnel)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              AppStrings.common.cancel,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final parsed = double.tryParse(
                amountCtrl.text.replaceAll(',', '.'),
              );
              final capped = parsed?.clamp(0.01, tx.amount.abs());
              _reverseTransaction(
                reason: reasonCtrl.text,
                amount: capped,
              );
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog() async {
    final amountCtrl = TextEditingController(
      text: widget.transaction.amount.toStringAsFixed(2),
    );
    final noteCtrl = TextEditingController(text: widget.transaction.note ?? '');
    var pickedDate = widget.transaction.date;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          title: Text(
            AppStrings.journal.editTransaction,
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.r10),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: pickedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (date != null) {
                      setLocalState(() => pickedDate = date);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(AppRadius.r10),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: AppColors.textDisabled,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat(
                            'dd MMMM yyyy',
                            'fr_FR',
                          ).format(pickedDate),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: InputDecoration(
                    labelText: AppStrings.journal.amountLabelCode(
                      AppFormats.currencyCode,
                    ),
                    prefixText: '${AppFormats.currencySymbol} ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: AppStrings.goals.noteOptional,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                AppStrings.common.cancel,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppStrings.common.save),
            ),
          ],
        ),
      ),
    );

    if (shouldSave != true) return;

    final parsedAmount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
    if (parsedAmount == null || parsedAmount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.journal.invalidAmount)));
      return;
    }

    setState(() => _loading = true);
    try {
      final tx = widget.transaction;
      await ref
          .read(apiClientProvider)
          .put(
            '/api/transactions/${tx.id}',
            data: {
              'accountId': tx.accountId,
              'date': DateFormat('yyyy-MM-dd').format(pickedDate),
              'amount': parsedAmount,
              'note': noteCtrl.text.trim().isEmpty
                  ? null
                  : noteCtrl.text.trim(),
              'status': tx.isCompleted ? 0 : 1,
              'isAuto': tx.isAuto,
            },
          );
      _afterMutation();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    final signedAmount = tx.signedAmount;
    final amountPrefix = signedAmount >= 0 ? '+' : '-';
    final amountColor = signedAmount >= 0
        ? AppColors.primary
        : AppColors.textPrimary;

    return AppPanel(
      padding: const EdgeInsets.all(AppSpacing.xl),
      radius: AppRadius.r16,
      variant: AppPanelVariant.elevated,
      borderColor: AppColors.borderSubtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.onClose != null)
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close),
                tooltip: AppStrings.common.close,
                color: AppColors.textSecondary,
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TransactionAvatar(transaction: tx, size: 54),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayLabel(tx),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.journal.transactionRef(
                        tx.id.substring(0, 8).toUpperCase(),
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$amountPrefix${AppFormats.formatFromChf(signedAmount.abs())}',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: amountColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _StatusPill(transaction: tx, compact: false),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: 20),
          Wrap(
            runSpacing: 16,
            spacing: 24,
            children: [
              _DetailField(
                label: AppStrings.journal.detailDate,
                icon: Icons.calendar_today,
                value: DateFormat('dd MMMM yyyy', 'fr_FR').format(tx.date),
              ),
              _DetailField(
                label: AppStrings.journal.detailAccount,
                icon: Icons.account_balance_wallet_outlined,
                value: tx.accountName ?? tx.accountId,
              ),
              _DetailField(
                label: AppStrings.journal.detailType,
                value: tx.isAuto
                    ? AppStrings.journal.typeAuto
                    : AppStrings.journal.typeManual,
                chipColor: tx.isAuto ? AppColors.primary : AppColors.info,
                isChip: true,
              ),
              _DetailField(
                label: AppStrings.journal.detailStatus,
                value: _statusLabel(tx),
                chipColor: tx.isVoided
                    ? AppColors.textDisabled
                    : tx.isReimbursement
                    ? AppColors.info
                    : tx.isCompleted
                    ? AppColors.primary
                    : AppColors.warning,
                isChip: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (tx.isPending) ...[
                _ActionTextButton(
                  icon: Icons.check_circle_outline,
                  label: AppStrings.journal.actionPay,
                  tooltip: AppStrings.journal.actionPayTooltip,
                  color: AppColors.primary,
                  loading: _loading,
                  onTap: _showValidateDialog,
                ),
              ],
              if (!tx.isVoided && !tx.isReimbursement)
                _ActionTextButton(
                  icon: Icons.undo_rounded,
                  label: 'Annuler',
                  tooltip: 'Annuler et creer un remboursement',
                  color: AppColors.warning,
                  loading: _loading,
                  onTap: _showReverseDialog,
                ),
              _ActionTextButton(
                icon: Icons.edit_outlined,
                label: AppStrings.journal.actionEdit,
                tooltip: AppStrings.journal.actionEdit,
                color: AppColors.textDisabled,
                onTap: _showEditDialog,
              ),
              _ActionTextButton(
                icon: Icons.print_outlined,
                label: AppStrings.journal.actionPrint,
                tooltip: AppStrings.journal.actionPrint,
                color: AppColors.textDisabled,
                onTap: () {},
              ),
            ],
          ),
          if ((tx.displayNote ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.s14),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppRadius.r10),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Text(
                tx.displayNote!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  final String label;
  final IconData? icon;
  final String value;
  final bool isChip;
  final Color? chipColor;

  const _DetailField({
    required this.label,
    this.icon,
    required this.value,
    this.isChip = false,
    this.chipColor,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textDisabled,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          if (isChip)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: (chipColor ?? AppColors.primary).withAlpha(24),
                borderRadius: BorderRadius.circular(AppRadius.r6),
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: chipColor ?? AppColors.primary,
                ),
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: AppColors.textDisabled),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final Transaction transaction;
  final bool compact;

  const _StatusPill({required this.transaction, this.compact = true});

  @override
  Widget build(BuildContext context) {
    // Only show status pill for unpaid transactions
    if (transaction.isCompleted) return const SizedBox.shrink();

    final label = _statusLabel(transaction);
    final color = AppColors.warning;
    final icon = Icons.schedule;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(AppRadius.r7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionGroupTag extends StatelessWidget {
  final String label;

  const _TransactionGroupTag({required this.label});

  static Color _colorFor(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('revenu') || lower.contains('salaire')) {
      return AppColors.primary;
    }
    if (lower.contains('invest') || lower.contains('bourse') ||
        lower.contains('epargne') || lower.contains('épargne')) {
      return AppColors.info;
    }
    if (lower.contains('abonn') || lower.contains('stream') ||
        lower.contains('media')) {
      return const Color(0xFF8B5CF6);
    }
    if (lower.contains('logement') || lower.contains('loyer') ||
        lower.contains('immob')) {
      return AppColors.warning;
    }
    if (lower.contains('transport') || lower.contains('auto') ||
        lower.contains('voiture')) {
      return const Color(0xFF06B6D4);
    }
    if (lower.contains('aliment') || lower.contains('nourriture') ||
        lower.contains('courses')) {
      return const Color(0xFFF97316);
    }
    // Hash-based fallback for unknown groups
    const palette = [
      Color(0xFF3B82F6),
      Color(0xFF8B5CF6),
      Color(0xFFF59E0B),
      Color(0xFFEC4899),
      Color(0xFF06B6D4),
      Color(0xFF10B981),
    ];
    return palette[label.hashCode.abs() % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(52)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}


class _ActionTextButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  final bool loading;

  const _ActionTextButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.color,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: TextButton.icon(
        onPressed: loading ? null : onTap,
        icon: loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, size: 16),
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        style: AppButtonStyles.tonal(
          foregroundColor: color,
          backgroundColor: color.withAlpha(22),
          radius: AppRadius.r8,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }
}

class _TransactionAvatar extends StatelessWidget {
  final Transaction transaction;
  final double size;
  const _TransactionAvatar({required this.transaction, required this.size});

  @override
  Widget build(BuildContext context) {
    final label = _displayLabel(transaction).toLowerCase();
    IconData icon;
    Color color;

    if (label.contains('spotify')) {
      icon = Icons.music_note;
      color = AppColors.successStrong;
    } else if (label.contains('netflix')) {
      icon = Icons.movie_filter;
      color = AppColors.danger;
    } else if (label.contains('loyer') || label.contains('rent')) {
      icon = Icons.home_outlined;
      color = AppColors.warning;
    } else if (label.contains('salaire') || label.contains('salary')) {
      icon = Icons.trending_up;
      color = AppColors.primary;
    } else if (transaction.isIncome) {
      icon = Icons.trending_up;
      color = AppColors.primary;
    } else {
      icon = Icons.receipt_long_outlined;
      color = AppColors.textDisabled;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}

String _displayLabel(Transaction tx) {
  final note = (tx.displayNote ?? '').trim();
  if (note.isNotEmpty) return note;
  final category = (tx.categoryName ?? '').trim();
  if (category.isNotEmpty) return category;
  return (tx.accountName ?? tx.accountId).trim();
}

String _transactionGroup(Transaction tx) {
  final group = (tx.accountGroup ?? '').trim();
  if (group.isNotEmpty) return group;
  final account = (tx.accountName ?? '').trim();
  if (account.isNotEmpty) return account;
  return tx.accountId.trim();
}


String _statusLabel(Transaction tx) {
  if (tx.isVoided) return 'Annulee';
  if (tx.isReimbursement) return 'Remboursement';
  if (tx.isCompleted) return AppStrings.journal.statusPaid;
  if (tx.isAuto) return AppStrings.journal.statusAutoUpcoming;
  return AppStrings.journal.statusToPay;
}
