import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/features/transactions/providers/transaction_refresh.dart';
import 'package:solver/features/transactions/models/transaction.dart';
import 'package:solver/features/transactions/providers/transactions_provider.dart';

final _monthNames = [
  '',
  'Janvier',
  'Février',
  'Mars',
  'Avril',
  'Mai',
  'Juin',
  'Juillet',
  'Août',
  'Septembre',
  'Octobre',
  'Novembre',
  'Décembre',
];

void showTransactionsListModal(
  BuildContext context,
  WidgetRef ref, {
  required String accountId,
  required String accountName,
  required bool isIncome,
  required int month,
  required int year,
}) {
  showDialog(
    context: context,
    builder: (_) => UncontrolledProviderScope(
      container: ProviderScope.containerOf(context),
      child: _TransactionsListDialog(
        accountId: accountId,
        accountName: accountName,
        isIncome: isIncome,
        month: month,
        year: year,
      ),
    ),
  );
}

class _TransactionsListDialog extends ConsumerWidget {
  final String accountId;
  final String accountName;
  final bool isIncome;
  final int month;
  final int year;

  const _TransactionsListDialog({
    required this.accountId,
    required this.accountName,
    required this.isIncome,
    required this.month,
    required this.year,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (accountId: accountId, month: month, year: year);
    final txAsync = ref.watch(transactionsByAccountMonthProvider(key));
    final color = isIncome ? AppColors.neonEmerald : AppColors.softRed;

    return Dialog(
      backgroundColor: AppColors.surfaceDialog,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: EdgeInsets.all(
            MediaQuery.of(context).size.width < 500 ? 16 : 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          accountName,
                          style: TextStyle(
                            color: color,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${_monthNames[month]} $year',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.borderSubtle),
              const SizedBox(height: 8),

              // List
              Flexible(
                child: txAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text(
                      'Erreur: $e',
                      style: const TextStyle(color: AppColors.softRed),
                    ),
                  ),
                  data: (transactions) {
                    if (transactions.isEmpty) {
                      return const Center(
                        child: Text(
                          'Aucune transaction ce mois',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: transactions.length,
                      separatorBuilder: (_, _) => const Divider(
                        color: AppColors.borderSubtle,
                        height: 1,
                      ),
                      itemBuilder: (context, i) => _TransactionTile(
                        transaction: transactions[i],
                        isIncome: isIncome,
                        onValidated: () {
                          ref.invalidate(
                            transactionsByAccountMonthProvider(key),
                          );
                          invalidateAfterTransactionMutation(ref);
                        },
                        onDeleted: () {
                          ref.invalidate(
                            transactionsByAccountMonthProvider(key),
                          );
                          invalidateAfterTransactionMutation(ref);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionTile extends ConsumerStatefulWidget {
  final Transaction transaction;
  final bool isIncome;
  final VoidCallback onValidated;
  final VoidCallback onDeleted;

  const _TransactionTile({
    required this.transaction,
    required this.isIncome,
    required this.onValidated,
    required this.onDeleted,
  });

  @override
  ConsumerState<_TransactionTile> createState() => _TransactionTileState();
}

class _TransactionTileState extends ConsumerState<_TransactionTile> {
  bool _loading = false;

  Future<void> _validate({double? overrideAmount}) async {
    setState(() => _loading = true);
    try {
      final client = ref.read(apiClientProvider);
      final t = widget.transaction;
      await client.put(
        '/api/transactions/${t.id}',
        data: {
          'accountId': t.accountId,
          'date': DateFormat('yyyy-MM-dd').format(t.date),
          'amount': overrideAmount ?? t.amount,
          'note': t.note,
          'status': 0,
          'isAuto': t.isAuto,
        },
      );
      widget.onValidated();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _loading = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.delete('/api/transactions/${widget.transaction.id}');
      widget.onDeleted();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showValidateDialog() {
    final amountCtrl = TextEditingController(
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
          'Valider la transaction',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Modifier le montant si nécessaire :',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Montant (${AppFormats.currencyCode})',
                prefixText: '${AppFormats.currencySymbol} ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Annuler',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              final amount = double.tryParse(
                amountCtrl.text.replaceAll(',', '.'),
              );
              _validate(overrideAmount: amount);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transaction;
    final color = widget.isIncome ? AppColors.neonEmerald : AppColors.softRed;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.isPending ? AppColors.warmAmber : color,
            ),
          ),
          const SizedBox(width: 12),

          // Date + note
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('dd MMM', 'fr_FR').format(t.date),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                if (t.note != null && t.note!.isNotEmpty)
                  Text(
                    t.note!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                if (t.isAuto)
                  const Text(
                    'Auto',
                    style: TextStyle(
                      color: AppColors.textDisabled,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),

          // Amount
          Text(
            AppFormats.currency.format(t.amount),
            style: TextStyle(
              color: t.isPending ? AppColors.textSecondary : color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),

          // Actions (only for pending)
          if (t.isPending) ...[
            const SizedBox(width: 8),
            if (_loading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Validate
                  IconButton(
                    icon: const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.neonEmerald,
                      size: 20,
                    ),
                    onPressed: _showValidateDialog,
                    tooltip: 'Valider',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                  // Delete
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.softRed,
                      size: 20,
                    ),
                    onPressed: _delete,
                    tooltip: 'Supprimer',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}
