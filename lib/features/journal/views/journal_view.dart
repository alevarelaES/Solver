import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/features/accounts/providers/accounts_provider.dart';
import 'package:solver/features/journal/providers/journal_provider.dart';
import 'package:solver/features/transactions/models/transaction.dart';
import 'package:solver/features/transactions/providers/transaction_refresh.dart';
import 'package:solver/features/transactions/widgets/transaction_form_modal.dart';

const _months = [
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

// ── Selected transaction ────────────────────────────────────────────────────
final _selectedTxProvider = StateProvider<Transaction?>((ref) => null);

// ── Search query ────────────────────────────────────────────────────────────
final _searchQueryProvider = StateProvider<String>((ref) => '');

// ── Pagination ──────────────────────────────────────────────────────────────
const _pageSize = 20;
final _currentPageProvider = StateProvider<int>((ref) => 0);

// ═══════════════════════════════════════════════════════════════════════════════
// JOURNAL VIEW
// ═══════════════════════════════════════════════════════════════════════════════
class JournalView extends ConsumerWidget {
  const JournalView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(journalTransactionsProvider);

    return txAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Erreur: $e',
          style: const TextStyle(color: AppColors.danger),
        ),
      ),
      data: (transactions) {
        // Apply search filter client-side
        final query = ref.watch(_searchQueryProvider).toLowerCase();
        final filtered = query.isEmpty
            ? transactions
            : transactions.where((t) {
                final name = (t.accountName ?? t.accountId).toLowerCase();
                final note = (t.note ?? '').toLowerCase();
                return name.contains(query) || note.contains(query);
              }).toList();

        // Auto-select first when nothing is selected
        final selected = ref.watch(_selectedTxProvider);
        if (selected == null && filtered.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(_selectedTxProvider.notifier).state = filtered.first;
          });
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isTablet =
                constraints.maxWidth >= 768 && constraints.maxWidth < 1024;
            final isMobile = constraints.maxWidth < 768;

            return Column(
              children: [
                _JournalHeader(isMobile: isMobile),
                _JournalFilterBar(isMobile: isMobile),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'Aucune transaction',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : isMobile
                      ? _MobileList(transactions: filtered)
                      : Row(
                          children: [
                            SizedBox(
                              width: isTablet ? 280 : 340,
                              child: _LeftPanel(transactions: filtered),
                            ),
                            Container(width: 1, color: AppColors.borderSubtle),
                            Expanded(
                              child: _RightPanel(transactions: filtered),
                            ),
                          ],
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HEADER — Title + Search + Add Entry
// ═══════════════════════════════════════════════════════════════════════════════
class _JournalHeader extends ConsumerWidget {
  final bool isMobile;
  const _JournalHeader({required this.isMobile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: _TitleBlock()),
                    _AddEntryButton(compact: true),
                  ],
                ),
                const SizedBox(height: 12),
                const _SearchBar(),
              ],
            )
          : Row(
              children: [
                const _TitleBlock(),
                const SizedBox(width: 32),
                const Expanded(child: _SearchBar()),
                const SizedBox(width: 16),
                _AddEntryButton(compact: false),
              ],
            ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Journal des Transactions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        SizedBox(height: 2),
        Text(
          'Gérer et vérifier vos activités financières',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _SearchBar extends ConsumerWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      child: TextField(
        onChanged: (v) {
          ref.read(_searchQueryProvider.notifier).state = v;
          ref.read(_currentPageProvider.notifier).state = 0;
        },
        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Rechercher une transaction…',
          hintStyle: const TextStyle(
            fontSize: 13,
            color: AppColors.textDisabled,
          ),
          prefixIcon: const Icon(
            Icons.search,
            size: 18,
            color: AppColors.textDisabled,
          ),
          filled: true,
          fillColor: AppColors.surfaceElevated,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: const BorderSide(color: AppColors.borderSubtle),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: const BorderSide(color: AppColors.borderSubtle),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _AddEntryButton extends ConsumerWidget {
  final bool compact;
  const _AddEntryButton({required this.compact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton.icon(
      onPressed: () => showTransactionFormModal(context, ref),
      icon: const Icon(Icons.add, size: 16),
      label: Text(
        compact ? 'Ajouter' : 'Nouvelle écriture',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FILTER BAR — Chips
// ═══════════════════════════════════════════════════════════════════════════════
class _JournalFilterBar extends ConsumerWidget {
  final bool isMobile;
  const _JournalFilterBar({required this.isMobile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(journalFiltersProvider);
    final accountsAsync = ref.watch(accountsProvider);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: 10,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              icon: Icons.calendar_today,
              label: '${filters.year}',
              onTap: () => _pickYear(context, ref, filters),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              icon: Icons.date_range,
              label: filters.month != null
                  ? _months[filters.month!]
                  : 'Tous les mois',
              onTap: () => _pickMonth(context, ref, filters),
            ),
            const SizedBox(width: 8),
            accountsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (accounts) {
                final selected = filters.accountId != null
                    ? accounts.firstWhere(
                        (a) => a.id == filters.accountId,
                        orElse: () => accounts.first,
                      )
                    : null;
                return _FilterChip(
                  icon: Icons.account_balance_wallet,
                  label: selected?.name ?? 'Tous les comptes',
                  onTap: () => _pickAccount(context, ref, filters, accounts),
                );
              },
            ),
            const SizedBox(width: 8),
            _FilterChip(
              icon: Icons.verified_user,
              label: filters.status == 'completed'
                  ? 'Payés'
                  : filters.status == 'pending'
                  ? 'En attente'
                  : 'Tous statuts',
              onTap: () => _cycleStatus(ref, filters),
            ),
          ],
        ),
      ),
    );
  }

  void _pickYear(BuildContext context, WidgetRef ref, JournalFilters filters) {
    final now = DateTime.now();
    showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text(
          'Année',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        children: List.generate(6, (i) {
          final y = now.year - i;
          return SimpleDialogOption(
            onPressed: () {
              ref.read(journalFiltersProvider.notifier).state = filters
                  .copyWith(year: y, month: null);
              ref.read(_currentPageProvider.notifier).state = 0;
              Navigator.pop(context);
            },
            child: Text(
              '$y',
              style: TextStyle(
                color: y == filters.year
                    ? AppColors.primary
                    : AppColors.textPrimary,
              ),
            ),
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
        title: const Text(
          'Mois',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        children: [
          SimpleDialogOption(
            onPressed: () {
              ref.read(journalFiltersProvider.notifier).state = filters
                  .copyWith(month: null);
              ref.read(_currentPageProvider.notifier).state = 0;
              Navigator.pop(context);
            },
            child: const Text(
              'Tous',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
          ...List.generate(12, (i) {
            final m = i + 1;
            return SimpleDialogOption(
              onPressed: () {
                ref.read(journalFiltersProvider.notifier).state = filters
                    .copyWith(month: m);
                ref.read(_currentPageProvider.notifier).state = 0;
                Navigator.pop(context);
              },
              child: Text(
                _months[m],
                style: TextStyle(
                  color: m == filters.month
                      ? AppColors.primary
                      : AppColors.textPrimary,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _pickAccount(
    BuildContext context,
    WidgetRef ref,
    JournalFilters filters,
    List accounts,
  ) {
    showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text(
          'Compte',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        children: [
          SimpleDialogOption(
            onPressed: () {
              ref.read(journalFiltersProvider.notifier).state = filters
                  .copyWith(accountId: null);
              ref.read(_currentPageProvider.notifier).state = 0;
              Navigator.pop(context);
            },
            child: const Text(
              'Tous',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
          ...accounts.map(
            (a) => SimpleDialogOption(
              onPressed: () {
                ref.read(journalFiltersProvider.notifier).state = filters
                    .copyWith(accountId: a.id);
                ref.read(_currentPageProvider.notifier).state = 0;
                Navigator.pop(context);
              },
              child: Text(
                a.name,
                style: TextStyle(
                  color: a.id == filters.accountId
                      ? AppColors.primary
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ),
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
    ref.read(journalFiltersProvider.notifier).state = filters.copyWith(
      status: next,
    );
    ref.read(_currentPageProvider.notifier).state = 0;
  }
}

class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FilterChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          border: Border.all(color: AppColors.borderSubtle),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.expand_more,
              size: 14,
              color: AppColors.textDisabled,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LEFT PANEL — Transaction list + pagination
// ═══════════════════════════════════════════════════════════════════════════════
class _LeftPanel extends ConsumerWidget {
  final List<Transaction> transactions;
  const _LeftPanel({required this.transactions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(_currentPageProvider);
    final totalPages = (transactions.length / _pageSize).ceil();
    final start = page * _pageSize;
    final end = (start + _pageSize).clamp(0, transactions.length);
    final pageItems = transactions.sublist(start, end);
    final selected = ref.watch(_selectedTxProvider);

    return Container(
      color: AppColors.surfaceCard,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: pageItems.length,
              itemBuilder: (context, i) {
                final tx = pageItems[i];
                final isSelected = selected?.id == tx.id;
                return _TransactionListItem(
                  transaction: tx,
                  isSelected: isSelected,
                  onTap: () =>
                      ref.read(_selectedTxProvider.notifier).state = tx,
                );
              },
            ),
          ),
          // Pagination footer
          if (totalPages > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: AppColors.surfaceElevated,
                border: Border(top: BorderSide(color: AppColors.borderSubtle)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: page > 0
                        ? () => ref.read(_currentPageProvider.notifier).state =
                              page - 1
                        : null,
                    icon: const Icon(Icons.chevron_left, size: 18),
                    color: AppColors.textDisabled,
                    disabledColor: AppColors.textDisabled.withAlpha(80),
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                  Text(
                    'Page ${page + 1} sur $totalPages',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDisabled,
                      letterSpacing: 0.5,
                    ),
                  ),
                  IconButton(
                    onPressed: page < totalPages - 1
                        ? () => ref.read(_currentPageProvider.notifier).state =
                              page + 1
                        : null,
                    icon: const Icon(Icons.chevron_right, size: 18),
                    color: AppColors.textDisabled,
                    disabledColor: AppColors.textDisabled.withAlpha(80),
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Single transaction item in left panel ──────────────────────────────────
class _TransactionListItem extends StatelessWidget {
  final Transaction transaction;
  final bool isSelected;
  final VoidCallback onTap;

  const _TransactionListItem({
    required this.transaction,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final isIncome = t.accountType == 'income';
    final amountColor = isIncome ? AppColors.primary : AppColors.textPrimary;
    final amountPrefix = isIncome ? '+' : '-';

    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withAlpha(12)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 4,
            ),
            bottom: const BorderSide(color: AppColors.borderSubtle, width: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date + Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat(
                    'dd MMM yyyy',
                    'fr_FR',
                  ).format(t.date).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDisabled,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '$amountPrefix${AppFormats.currency.format(t.amount)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: amountColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Icon + Name
            Row(
              children: [
                _TransactionIcon(transaction: t, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t.note?.isNotEmpty == true
                        ? t.note!
                        : (t.accountName ?? t.accountId),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (t.isAuto)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.bolt,
                      size: 12,
                      color: AppColors.textDisabled,
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

// ═══════════════════════════════════════════════════════════════════════════════
// RIGHT PANEL — Detail view
// ═══════════════════════════════════════════════════════════════════════════════
class _RightPanel extends ConsumerWidget {
  final List<Transaction> transactions;
  const _RightPanel({required this.transactions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_selectedTxProvider);
    if (selected == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, size: 48, color: AppColors.textDisabled),
            SizedBox(height: 12),
            Text(
              'Sélectionnez une transaction',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return _DetailView(transaction: selected);
  }
}

class _DetailView extends ConsumerStatefulWidget {
  final Transaction transaction;
  const _DetailView({required this.transaction});

  @override
  ConsumerState<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends ConsumerState<_DetailView> {
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
      _onChanged();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _loading = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.delete('/api/transactions/${widget.transaction.id}');
      ref.read(_selectedTxProvider.notifier).state = null;
      _onChanged();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onChanged() {
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
          'Valider la transaction',
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
    final amountPrefix = isIncome ? '+' : '-';

    return Container(
      color: AppColors.surfaceElevated,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Main card ────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.borderSubtle),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(10),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: icon + name + amount
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TransactionIcon(transaction: t, size: 56),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.note?.isNotEmpty == true
                                      ? t.note!
                                      : (t.accountName ?? t.accountId),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Transaction #${t.id.substring(0, 8).toUpperCase()}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$amountPrefix${AppFormats.currency.format(t.amount)}',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: isIncome
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _StatusBadge(transaction: t),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),
                      const Divider(color: AppColors.borderSubtle, height: 1),
                      const SizedBox(height: 24),

                      // Detail grid
                      _DetailGrid(transaction: t),

                      const SizedBox(height: 32),
                      const Divider(color: AppColors.borderSubtle, height: 1),
                      const SizedBox(height: 20),

                      // Actions row
                      Row(
                        children: [
                          if (t.isPending) ...[
                            _ActionButton(
                              icon: Icons.check_circle_outline,
                              color: AppColors.primary,
                              tooltip: 'Valider',
                              loading: _loading,
                              onTap: _showValidateDialog,
                            ),
                            const SizedBox(width: 4),
                          ],
                          _ActionButton(
                            icon: Icons.edit_outlined,
                            color: AppColors.textDisabled,
                            tooltip: 'Modifier',
                            onTap: () => showTransactionFormModal(context, ref),
                          ),
                          const SizedBox(width: 4),
                          _ActionButton(
                            icon: Icons.print_outlined,
                            color: AppColors.textDisabled,
                            tooltip: 'Imprimer',
                            onTap: () {},
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _delete,
                            icon: const Icon(Icons.delete_outline, size: 14),
                            label: const Text(
                              'Supprimer',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.danger,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                                side: BorderSide(
                                  color: AppColors.danger.withAlpha(25),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Notes section ────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard.withAlpha(128),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: AppColors.borderSubtle,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NOTES',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDisabled,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        t.note?.isNotEmpty == true
                            ? t.note!
                            : 'Aucune note attachée à cette transaction.',
                        style: TextStyle(
                          fontSize: 13,
                          color: t.note?.isNotEmpty == true
                              ? AppColors.textPrimary
                              : AppColors.textDisabled,
                          fontStyle: t.note?.isNotEmpty == true
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Detail grid (Date, Account, Status) ────────────────────────────────────
class _DetailGrid extends StatelessWidget {
  final Transaction transaction;
  const _DetailGrid({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 400;
        final children = [
          _DetailField(
            label: 'DATE',
            icon: Icons.calendar_today,
            value: DateFormat('dd MMMM yyyy', 'fr_FR').format(t.date),
          ),
          _DetailField(
            label: 'COMPTE',
            icon: Icons.credit_card,
            value: t.accountName ?? t.accountId,
          ),
          _DetailField(
            label: 'TYPE',
            isChip: true,
            chipColor: t.isAuto ? AppColors.primary : const Color(0xFFF97316),
            value: t.isAuto ? 'Automatique' : 'Manuel',
          ),
          _DetailField(
            label: 'STATUT',
            isChip: true,
            chipColor: t.isCompleted ? AppColors.primary : AppColors.warning,
            value: t.isCompleted ? 'Vérifié' : 'En attente',
          ),
        ];

        if (isWide) {
          return Wrap(spacing: 40, runSpacing: 20, children: children);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children
              .map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: c,
                ),
              )
              .toList(),
        );
      },
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textDisabled,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        isChip
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: chipColor?.withAlpha(25),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: chipColor,
                    letterSpacing: 0.5,
                  ),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 14, color: AppColors.textDisabled),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
      ],
    );
  }
}

// ─── Status badge ───────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final Transaction transaction;
  const _StatusBadge({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isVerified = transaction.isCompleted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isVerified ? Icons.check_circle : Icons.schedule,
          size: 14,
          color: isVerified ? AppColors.primary : AppColors.warning,
        ),
        const SizedBox(width: 4),
        Text(
          isVerified ? 'VÉRIFIÉ' : 'EN ATTENTE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isVerified ? AppColors.primary : AppColors.warning,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ─── Action icon button ─────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  final bool loading;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}

// ─── Transaction icon ───────────────────────────────────────────────────────
class _TransactionIcon extends StatelessWidget {
  final Transaction transaction;
  final double size;
  const _TransactionIcon({required this.transaction, required this.size});

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.accountType == 'income';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isIncome
            ? AppColors.primary.withAlpha(25)
            : const Color(0xFFF3F4F6),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.borderSubtle, width: 0.5),
      ),
      child: Icon(
        isIncome ? Icons.trending_up : Icons.receipt_long,
        size: size * 0.45,
        color: isIncome ? AppColors.primary : AppColors.textDisabled,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MOBILE LIST — Full-width list, tap opens detail in bottom sheet
// ═══════════════════════════════════════════════════════════════════════════════
class _MobileList extends ConsumerWidget {
  final List<Transaction> transactions;
  const _MobileList({required this.transactions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(_currentPageProvider);
    final totalPages = (transactions.length / _pageSize).ceil();
    final start = page * _pageSize;
    final end = (start + _pageSize).clamp(0, transactions.length);
    final pageItems = transactions.sublist(start, end);

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 20),
            itemCount: pageItems.length,
            itemBuilder: (context, i) {
              final tx = pageItems[i];
              return _TransactionListItem(
                transaction: tx,
                isSelected: false,
                onTap: () => _showMobileDetail(context, ref, tx),
              );
            },
          ),
        ),
        if (totalPages > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.surfaceElevated,
              border: Border(top: BorderSide(color: AppColors.borderSubtle)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: page > 0
                      ? () => ref.read(_currentPageProvider.notifier).state =
                            page - 1
                      : null,
                  icon: const Icon(Icons.chevron_left, size: 18),
                  color: AppColors.textDisabled,
                ),
                Text(
                  'Page ${page + 1} sur $totalPages',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDisabled,
                  ),
                ),
                IconButton(
                  onPressed: page < totalPages - 1
                      ? () => ref.read(_currentPageProvider.notifier).state =
                            page + 1
                      : null,
                  icon: const Icon(Icons.chevron_right, size: 18),
                  color: AppColors.textDisabled,
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _showMobileDetail(BuildContext context, WidgetRef ref, Transaction tx) {
    ref.read(_selectedTxProvider.notifier).state = tx;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, controller) => Container(
            decoration: const BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.xxl),
              ),
            ),
            child: Column(
              children: [
                // Drag handle
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textDisabled.withAlpha(60),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Expanded(child: _DetailView(transaction: tx)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
