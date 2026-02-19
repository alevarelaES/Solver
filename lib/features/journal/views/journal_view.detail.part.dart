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

  Future<void> _delete() async {
    setState(() => _loading = true);
    try {
      await ref
          .read(apiClientProvider)
          .delete('/api/transactions/${widget.transaction.id}');
      ref.read(_selectedTxIdProvider.notifier).state = null;
      _afterMutation();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _afterMutation() {
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
        title: const Text(
          'Marquer comme payee',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: 'Montant (${AppFormats.currencyCode})',
            prefixText: '${AppFormats.currencySymbol} ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Annuler',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final amount = double.tryParse(ctrl.text.replaceAll(',', '.'));
              _validate(overrideAmount: amount);
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
          title: const Text(
            'Modifier la transaction',
            style: TextStyle(color: AppColors.textPrimary),
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
                    labelText: 'Montant (${AppFormats.currencyCode})',
                    prefixText: '${AppFormats.currencySymbol} ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Note (optionnel)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Annuler',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enregistrer'),
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
      ).showSnackBar(const SnackBar(content: Text('Montant invalide')));
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
    final amountPrefix = tx.isIncome ? '+' : '-';
    final amountColor = tx.isIncome ? AppColors.primary : AppColors.textPrimary;

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
                tooltip: 'Fermer',
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
                      'Transaction #${tx.id.substring(0, 8).toUpperCase()}',
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
                    '$amountPrefix${AppFormats.currency.format(tx.amount)}',
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
                label: 'Date',
                icon: Icons.calendar_today,
                value: DateFormat('dd MMMM yyyy', 'fr_FR').format(tx.date),
              ),
              _DetailField(
                label: 'Compte',
                icon: Icons.account_balance_wallet_outlined,
                value: tx.accountName ?? tx.accountId,
              ),
              _DetailField(
                label: 'Type',
                value: tx.isAuto ? 'Automatique' : 'Manuel',
                chipColor: tx.isAuto ? AppColors.primary : AppColors.info,
                isChip: true,
              ),
              _DetailField(
                label: 'Statut',
                value: _statusLabel(tx),
                chipColor: tx.isCompleted
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
                  label: 'Payer',
                  tooltip: 'Marquer payee',
                  color: AppColors.primary,
                  loading: _loading,
                  onTap: _showValidateDialog,
                ),
              ],
              _ActionTextButton(
                icon: Icons.edit_outlined,
                label: 'Modifier',
                tooltip: 'Modifier',
                color: AppColors.textDisabled,
                onTap: _showEditDialog,
              ),
              _ActionTextButton(
                icon: Icons.print_outlined,
                label: 'Imprimer',
                tooltip: 'Imprimer',
                color: AppColors.textDisabled,
                onTap: () {},
              ),
              TextButton.icon(
                onPressed: _loading ? null : _delete,
                icon: const Icon(Icons.delete_outline, size: 15),
                label: const Text(
                  'Supprimer',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                style: AppButtonStyles.dangerOutline(radius: AppRadius.r9),
              ),
            ],
          ),
          if ((tx.note ?? '').isNotEmpty) ...[
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
                tx.note!,
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withAlpha(52)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}

class _FadedInlineText extends StatelessWidget {
  final String text;
  final Color fadeColor;

  const _FadedInlineText({required this.text, required this.fadeColor});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 0) return const SizedBox.shrink();
        final fadeWidth = (constraints.maxWidth * 0.38)
            .clamp(32.0, 86.0)
            .toDouble();
        return Stack(
          children: [
            Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  width: fadeWidth,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [fadeColor.withAlpha(0), fadeColor],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
  final note = (tx.note ?? '').trim();
  if (note.isNotEmpty) return note;
  final category = (tx.categoryName ?? '').trim();
  if (category.isNotEmpty) return category;
  return (tx.accountName ?? tx.accountId).trim();
}

String _transactionGroup(Transaction tx) {
  final group = (tx.categoryGroup ?? '').trim();
  if (group.isNotEmpty) return group;
  final category = (tx.categoryName ?? '').trim();
  if (category.isNotEmpty) return category;
  final account = (tx.accountName ?? '').trim();
  if (account.isNotEmpty) return account;
  return tx.accountId.trim();
}

String? _transactionDescription(Transaction tx) {
  final note = (tx.note ?? '').trim();
  if (note.isEmpty) return null;
  return note;
}

String _statusLabel(Transaction tx) {
  if (tx.isCompleted) return 'Paye';
  if (tx.isAuto) return 'Auto a venir';
  return 'A payer';
}

