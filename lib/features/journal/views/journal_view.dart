import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/core/theme/app_text_styles.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/features/accounts/providers/accounts_provider.dart';
import 'package:solver/features/dashboard/providers/dashboard_provider.dart';
import 'package:solver/features/journal/providers/journal_provider.dart';
import 'package:solver/features/transactions/models/transaction.dart';
import 'package:solver/features/transactions/widgets/transaction_form_modal.dart';
const _months = ['', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];

class JournalView extends ConsumerWidget {
  const JournalView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(journalTransactionsProvider);

    return Column(
      children: [
        const _JournalFilterBar(),
        Expanded(
          child: txAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('Erreur: $e', style: const TextStyle(color: AppColors.softRed)),
            ),
            data: (transactions) {
              if (transactions.isEmpty) {
                return const Center(
                  child: Text(
                    'Aucune transaction',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }
              // Group by month
              final groups = _groupByMonth(transactions);
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 100),
                itemCount: groups.length,
                itemBuilder: (context, i) {
                  final entry = groups[i];
                  if (entry is _MonthHeader) {
                    return _MonthHeaderWidget(label: entry.label);
                  } else {
                    final tx = entry as Transaction;
                    return _JournalTile(
                      transaction: tx,
                      onChanged: () {
                        ref.invalidate(journalTransactionsProvider);
                        ref.invalidate(dashboardDataProvider);
                      },
                    );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  List<dynamic> _groupByMonth(List<Transaction> transactions) {
    final result = <dynamic>[];
    String? currentKey;
    for (final tx in transactions) {
      final key = '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}';
      if (key != currentKey) {
        currentKey = key;
        result.add(_MonthHeader('${_months[tx.date.month]} ${tx.date.year}'));
      }
      result.add(tx);
    }
    return result;
  }
}

class _MonthHeader {
  final String label;
  const _MonthHeader(this.label);
}

// ─── Filter bar ───────────────────────────────────────────────────────────────
class _JournalFilterBar extends ConsumerWidget {
  const _JournalFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(journalFiltersProvider);
    final accountsAsync = ref.watch(accountsProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Year
          _FilterChip(
            label: '${filters.year}',
            onTap: () => _pickYear(context, ref, filters),
          ),
          // Month
          _FilterChip(
            label: filters.month != null ? _months[filters.month!] : 'Tous les mois',
            onTap: () => _pickMonth(context, ref, filters),
          ),
          // Account
          accountsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (accounts) {
              final selected = filters.accountId != null
                  ? accounts.firstWhere((a) => a.id == filters.accountId,
                      orElse: () => accounts.first)
                  : null;
              return _FilterChip(
                label: selected?.name ?? 'Tous les comptes',
                onTap: () => _pickAccount(context, ref, filters, accounts),
              );
            },
          ),
          // Status
          _FilterChip(
            label: filters.status == 'completed'
                ? 'Payés'
                : filters.status == 'pending'
                    ? 'En attente'
                    : 'Tous statuts',
            onTap: () => _cycleStatus(ref, filters),
          ),
          // Add button
          TextButton.icon(
            onPressed: () => showTransactionFormModal(context, ref),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Ajouter'),
            style: TextButton.styleFrom(foregroundColor: AppColors.electricBlue),
          ),
        ],
      ),
    );
  }

  void _pickYear(BuildContext context, WidgetRef ref, JournalFilters filters) {
    final now = DateTime.now();
    showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Année', style: TextStyle(color: AppColors.textPrimary)),
        children: List.generate(6, (i) {
          final y = now.year - i;
          return SimpleDialogOption(
            onPressed: () {
              ref.read(journalFiltersProvider.notifier).state =
                  filters.copyWith(year: y, month: null);
              Navigator.pop(context);
            },
            child: Text('$y',
                style: TextStyle(
                    color: y == filters.year
                        ? AppColors.electricBlue
                        : AppColors.textPrimary)),
          );
        }),
      ),
    );
  }

  void _pickMonth(BuildContext context, WidgetRef ref, JournalFilters filters) {
    showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Mois', style: TextStyle(color: AppColors.textPrimary)),
        children: [
          SimpleDialogOption(
            onPressed: () {
              ref.read(journalFiltersProvider.notifier).state =
                  filters.copyWith(month: null);
              Navigator.pop(context);
            },
            child: const Text('Tous', style: TextStyle(color: AppColors.textPrimary)),
          ),
          ...List.generate(12, (i) {
            final m = i + 1;
            return SimpleDialogOption(
              onPressed: () {
                ref.read(journalFiltersProvider.notifier).state =
                    filters.copyWith(month: m);
                Navigator.pop(context);
              },
              child: Text(_months[m],
                  style: TextStyle(
                      color: m == filters.month
                          ? AppColors.electricBlue
                          : AppColors.textPrimary)),
            );
          }),
        ],
      ),
    );
  }

  void _pickAccount(BuildContext context, WidgetRef ref, JournalFilters filters,
      List accounts) {
    showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Compte', style: TextStyle(color: AppColors.textPrimary)),
        children: [
          SimpleDialogOption(
            onPressed: () {
              ref.read(journalFiltersProvider.notifier).state =
                  filters.copyWith(accountId: null);
              Navigator.pop(context);
            },
            child: const Text('Tous', style: TextStyle(color: AppColors.textPrimary)),
          ),
          ...accounts.map((a) => SimpleDialogOption(
                onPressed: () {
                  ref.read(journalFiltersProvider.notifier).state =
                      filters.copyWith(accountId: a.id);
                  Navigator.pop(context);
                },
                child: Text(a.name,
                    style: TextStyle(
                        color: a.id == filters.accountId
                            ? AppColors.electricBlue
                            : AppColors.textPrimary)),
              )),
        ],
      ),
    );
  }

  void _cycleStatus(WidgetRef ref, JournalFilters filters) {
    final next = filters.status == null
        ? 'pending'
        : filters.status == 'pending'
            ? 'completed'
            : null;
    ref.read(journalFiltersProvider.notifier).state = filters.copyWith(status: next);
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.borderSubtle),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Text(label,
            style: AppTextStyles.label),
      ),
    );
  }
}

// ─── Month header ─────────────────────────────────────────────────────────────
class _MonthHeaderWidget extends StatelessWidget {
  final String label;
  const _MonthHeaderWidget({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: AppColors.surfaceCard,
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── Transaction tile ─────────────────────────────────────────────────────────
class _JournalTile extends ConsumerStatefulWidget {
  final Transaction transaction;
  final VoidCallback onChanged;

  const _JournalTile({required this.transaction, required this.onChanged});

  @override
  ConsumerState<_JournalTile> createState() => _JournalTileState();
}

class _JournalTileState extends ConsumerState<_JournalTile> {
  bool _loading = false;

  Future<void> _validate({double? overrideAmount}) async {
    setState(() => _loading = true);
    try {
      final client = ref.read(apiClientProvider);
      final t = widget.transaction;
      await client.put('/api/transactions/${t.id}', data: {
        'accountId': t.accountId,
        'date': DateFormat('yyyy-MM-dd').format(t.date),
        'amount': overrideAmount ?? t.amount,
        'note': t.note,
        'status': 'completed',
        'isAuto': t.isAuto,
      });
      widget.onChanged();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _loading = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.delete('/api/transactions/${widget.transaction.id}');
      widget.onChanged();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showActions() {
    final t = widget.transaction;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.accountName ?? 'Transaction',
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16)),
            const SizedBox(height: 4),
            Text(AppFormats.currency.format(t.amount),
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.check_circle_outline,
                  color: AppColors.neonEmerald),
              title: const Text('Valider',
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _showValidateDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.softRed),
              title: const Text('Supprimer',
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _delete();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showValidateDialog() {
    final ctrl = TextEditingController(
        text: widget.transaction.amount.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Valider la transaction',
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(labelText: 'Montant (CHF)', prefixText: 'CHF '),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final amount = double.tryParse(ctrl.text.replaceAll(',', '.'));
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
    final isIncome = t.accountType == 'income';
    final amountColor = isIncome ? AppColors.neonEmerald : AppColors.softRed;

    return InkWell(
      onTap: t.isPending ? _showActions : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // Status dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.isPending ? AppColors.warmAmber : amountColor,
              ),
            ),
            const SizedBox(width: 12),
            // Account name + note
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.accountName ?? t.accountId,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (t.isAuto)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.bolt,
                              size: 12, color: AppColors.textDisabled),
                        ),
                    ],
                  ),
                  if (t.note != null && t.note!.isNotEmpty)
                    Text(t.note!,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Date + amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  DateFormat('dd MMM', 'fr_FR').format(t.date),
                  style: const TextStyle(
                      color: AppColors.textDisabled, fontSize: 11),
                ),
                if (_loading)
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else
                  Text(
                    AppFormats.currency.format(t.amount),
                    style: TextStyle(
                      color: t.isPending
                          ? AppColors.textSecondary
                          : amountColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
