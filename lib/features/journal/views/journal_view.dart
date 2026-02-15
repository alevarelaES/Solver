import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/core/theme/app_component_styles.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/features/accounts/providers/accounts_provider.dart';
import 'package:solver/features/journal/providers/journal_provider.dart';
import 'package:solver/features/transactions/models/transaction.dart';
import 'package:solver/features/transactions/providers/transaction_refresh.dart';
import 'package:solver/features/transactions/widgets/transaction_form_modal.dart';
import 'package:solver/shared/widgets/app_panel.dart';

const _months = <String>[
  '',
  'Janvier',
  'Fevrier',
  'Mars',
  'Avril',
  'Mai',
  'Juin',
  'Juillet',
  'Aout',
  'Septembre',
  'Octobre',
  'Novembre',
  'Decembre',
];

final _selectedTxIdProvider = StateProvider<String?>((ref) => null);

class JournalView extends ConsumerWidget {
  const JournalView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(journalVisibleTransactionsProvider);
    final transactions = txAsync.valueOrNull ?? const <Transaction>[];

    if (txAsync.hasError && transactions.isEmpty) {
      return Center(
        child: Text(
          'Erreur: ${txAsync.error}',
          style: const TextStyle(color: AppColors.danger),
        ),
      );
    }
    if (txAsync.isLoading && transactions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final selectedId = ref.watch(_selectedTxIdProvider);
    final selected = selectedId == null
        ? null
        : transactions.where((t) => t.id == selectedId).firstOrNull;

    if (selectedId != null && selected == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(_selectedTxIdProvider.notifier).state = null;
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;
        return Stack(
          children: [
            Column(
              children: [
                _JournalHeader(isMobile: isMobile),
                Expanded(
                  child: _JournalBody(
                    transactions: transactions,
                    selected: selected,
                    isMobile: isMobile,
                  ),
                ),
              ],
            ),
            if (txAsync.isLoading)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (!isMobile && selected != null)
              _DesktopDetailOverlay(
                transaction: selected,
                onClose: () =>
                    ref.read(_selectedTxIdProvider.notifier).state = null,
              ),
          ],
        );
      },
    );
  }
}

class _JournalHeader extends ConsumerWidget {
  final bool isMobile;
  const _JournalHeader({required this.isMobile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headerPadding = isMobile
        ? const EdgeInsets.fromLTRB(16, 16, 16, 12)
        : const EdgeInsets.fromLTRB(28, 18, 28, 14);

    return Container(
      padding: headerPadding,
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
                const SizedBox(height: 10),
                const _SearchBar(),
              ],
            )
          : Row(
              children: [
                const Expanded(flex: 2, child: _TitleBlock()),
                const SizedBox(width: 20),
                Expanded(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: const _SearchBar(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        SizedBox(height: 2),
        Text(
          'Suivre les transactions, puis ouvrir le detail au clic.',
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
    return TextField(
      onChanged: (v) {
        ref.read(journalSearchProvider.notifier).state = v;
      },
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: AppInputStyles.search(
        hintText: 'Rechercher une transaction...',
        square: true,
        suffixIcon: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderSubtle),
            borderRadius: BorderRadius.zero,
          ),
          child: const Text(
            'K',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
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
        compact ? 'Ajouter' : 'Nouvelle ecriture',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      style: AppButtonStyles.tonal(
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        radius: 0,
      ),
    );
  }
}

class _JournalFilterBar extends ConsumerWidget {
  final bool isMobile;
  const _JournalFilterBar({required this.isMobile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(journalFiltersProvider);
    final columnFilters = ref.watch(journalColumnFiltersProvider);
    final now = DateTime.now();
    final defaultFocusMonth = filters.year == now.year ? now.month : 1;
    final monthLabel = filters.month != null
        ? _months[filters.month!]
        : 'Mois courant (${_months[defaultFocusMonth]})';
    final dateLabel = _dateFilterLabel(columnFilters);
    final textLabel = columnFilters.label.trim().isEmpty
        ? 'Tous libelles'
        : 'Libelle: ${columnFilters.label.trim()}';
    final amountLabel = _amountFilterLabel(columnFilters);
    final accountsAsync = ref.watch(accountsProvider);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: isMobile
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    icon: Icons.calendar_today,
                    label: '${filters.year}',
                    onTap: () => _pickYear(context, ref, filters),
                  ),
                  _FilterChip(
                    icon: Icons.date_range,
                    label: monthLabel,
                    onTap: () => _pickMonth(context, ref, filters),
                  ),
                  accountsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (accounts) {
                      final selected = filters.accountId == null
                          ? null
                          : accounts
                                .where((a) => a.id == filters.accountId)
                                .firstOrNull;
                      return _FilterChip(
                        icon: Icons.account_balance_wallet,
                        label: selected?.name ?? 'Tous les comptes',
                        onTap: () =>
                            _pickAccount(context, ref, filters, accounts),
                      );
                    },
                  ),
                  _FilterChip(
                    icon: Icons.fact_check_outlined,
                    label: _statusFilterLabel(filters.status),
                    onTap: () => _pickStatus(context, ref, filters),
                  ),
                  _FilterChip(
                    icon: Icons.event,
                    label: dateLabel,
                    onTap: () => _pickDateRange(context, ref, columnFilters),
                  ),
                  _FilterChip(
                    icon: Icons.label_outline,
                    label: textLabel,
                    onTap: () => _pickLabel(context, ref, columnFilters),
                  ),
                  _FilterChip(
                    icon: Icons.tune,
                    label: amountLabel,
                    onTap: () => _pickAmount(context, ref, columnFilters),
                  ),
                  if (columnFilters.hasActiveFilters)
                    _FilterChip(
                      icon: Icons.filter_alt_off_outlined,
                      label: 'Reinitialiser',
                      showChevron: false,
                      onTap: () => _clearColumnFilters(ref),
                    ),
                ],
              ),
            )
          : Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _FilterChip(
                        icon: Icons.calendar_today,
                        label: '${filters.year}',
                        expand: true,
                        onTap: () => _pickYear(context, ref, filters),
                      ),
                    ),
                    Expanded(
                      child: _FilterChip(
                        icon: Icons.date_range,
                        label: monthLabel,
                        expand: true,
                        onTap: () => _pickMonth(context, ref, filters),
                      ),
                    ),
                    Expanded(
                      child: accountsAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                        data: (accounts) {
                          final selected = filters.accountId == null
                              ? null
                              : accounts
                                    .where((a) => a.id == filters.accountId)
                                    .firstOrNull;
                          return _FilterChip(
                            icon: Icons.account_balance_wallet,
                            label: selected?.name ?? 'Tous les comptes',
                            expand: true,
                            onTap: () =>
                                _pickAccount(context, ref, filters, accounts),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: _FilterChip(
                        icon: Icons.fact_check_outlined,
                        label: _statusFilterLabel(filters.status),
                        expand: true,
                        onTap: () => _pickStatus(context, ref, filters),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 1, color: AppColors.borderSubtle),
                Row(
                  children: [
                    Expanded(
                      child: _FilterChip(
                        icon: Icons.event,
                        label: dateLabel,
                        expand: true,
                        onTap: () =>
                            _pickDateRange(context, ref, columnFilters),
                      ),
                    ),
                    Expanded(
                      child: _FilterChip(
                        icon: Icons.label_outline,
                        label: textLabel,
                        expand: true,
                        onTap: () => _pickLabel(context, ref, columnFilters),
                      ),
                    ),
                    Expanded(
                      child: _FilterChip(
                        icon: Icons.tune,
                        label: amountLabel,
                        expand: true,
                        onTap: () => _pickAmount(context, ref, columnFilters),
                      ),
                    ),
                    if (columnFilters.hasActiveFilters)
                      SizedBox(
                        width: 180,
                        child: _FilterChip(
                          icon: Icons.filter_alt_off_outlined,
                          label: 'Reinitialiser',
                          expand: true,
                          showChevron: false,
                          onTap: () => _clearColumnFilters(ref),
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }

  Future<void> _pickYear(
    BuildContext context,
    WidgetRef ref,
    JournalFilters filters,
  ) async {
    final now = DateTime.now();
    final selectedYear = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text(
          'Annee',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        children: List.generate(6, (i) {
          final year = now.year - i;
          return SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(year),
            child: Text(
              '$year',
              style: TextStyle(
                color: year == filters.year
                    ? AppColors.primary
                    : AppColors.textPrimary,
              ),
            ),
          );
        }),
      ),
    );
    if (selectedYear == null) return;
    ref.read(journalFiltersProvider.notifier).state = filters.copyWith(
      year: selectedYear,
      month: null,
    );
  }

  Future<void> _pickMonth(
    BuildContext context,
    WidgetRef ref,
    JournalFilters filters,
  ) async {
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text(
          'Mois',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(0),
            child: const Text(
              'Mois courant',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
          ...List.generate(12, (index) {
            final month = index + 1;
            return SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(month),
              child: Text(
                _months[month],
                style: TextStyle(
                  color: month == filters.month
                      ? AppColors.primary
                      : AppColors.textPrimary,
                ),
              ),
            );
          }),
        ],
      ),
    );
    if (selected == null) return;
    if (selected == 0) {
      ref.read(journalFiltersProvider.notifier).state = filters.copyWith(
        month: null,
      );
      return;
    }
    ref.read(journalFiltersProvider.notifier).state = filters.copyWith(
      month: selected,
    );
  }

  Future<void> _pickAccount(
    BuildContext context,
    WidgetRef ref,
    JournalFilters filters,
    List accounts,
  ) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text(
          'Compte',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop('__all__'),
            child: const Text(
              'Tous',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
          ...accounts.map((a) {
            return SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(a.id as String),
              child: Text(
                a.name,
                style: TextStyle(
                  color: a.id == filters.accountId
                      ? AppColors.primary
                      : AppColors.textPrimary,
                ),
              ),
            );
          }),
        ],
      ),
    );
    if (selected == null) return;
    ref.read(journalFiltersProvider.notifier).state = filters.copyWith(
      accountId: selected == '__all__' ? null : selected,
    );
  }

  Future<void> _pickStatus(
    BuildContext context,
    WidgetRef ref,
    JournalFilters filters,
  ) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text(
          'Statut',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop('__all__'),
            child: const Text(
              'Tous statuts',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop('pending'),
            child: const Text(
              'A payer',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop('completed'),
            child: const Text(
              'Payees',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
    if (selected == null) return;
    ref.read(journalFiltersProvider.notifier).state = filters.copyWith(
      status: selected == '__all__' ? null : selected,
    );
  }

  String _statusFilterLabel(String? status) {
    if (status == 'pending') return 'A payer';
    if (status == 'completed') return 'Payees';
    return 'Tous statuts';
  }

  String _dateFilterLabel(JournalColumnFilters filters) {
    final fmt = DateFormat('dd/MM/yyyy');
    final from = filters.fromDate;
    final to = filters.toDate;
    if (from == null && to == null) return 'Toutes dates';
    if (from != null && to != null) {
      if (_sameDay(from, to)) return 'Date: ${fmt.format(from)}';
      return 'Du ${fmt.format(from)} au ${fmt.format(to)}';
    }
    if (from != null) return 'A partir du ${fmt.format(from)}';
    return 'Jusqu au ${fmt.format(to!)}';
  }

  String _amountFilterLabel(JournalColumnFilters filters) {
    final min = filters.minAmount;
    final max = filters.maxAmount;
    if (min == null && max == null) return 'Tous montants';
    if (min != null && max != null) {
      return '${AppFormats.currency.format(min)} - ${AppFormats.currency.format(max)}';
    }
    if (min != null) return '>= ${AppFormats.currency.format(min)}';
    return '<= ${AppFormats.currency.format(max!)}';
  }

  Future<void> _pickDateRange(
    BuildContext context,
    WidgetRef ref,
    JournalColumnFilters filters,
  ) async {
    final picked = await showDialog<List<DateTime?>>(
      context: context,
      builder: (dialogContext) {
        var from = filters.fromDate;
        var to = filters.toDate;
        return StatefulBuilder(
          builder: (context, setLocalState) => AlertDialog(
            backgroundColor: AppColors.surfaceElevated,
            title: const Text(
              'Filtrer par date',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DateFilterInput(
                    label: 'Date min',
                    date: from,
                    onTap: () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: from ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (selected == null) return;
                      setLocalState(() => from = selected);
                    },
                    onClear: () => setLocalState(() => from = null),
                  ),
                  const SizedBox(height: 10),
                  _DateFilterInput(
                    label: 'Date max',
                    date: to,
                    onTap: () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: to ?? (from ?? DateTime.now()),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (selected == null) return;
                      setLocalState(() => to = selected);
                    },
                    onClear: () => setLocalState(() => to = null),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(
                  'Annuler',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(<DateTime?>[]),
                child: const Text(
                  'Effacer',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(<DateTime?>[from, to]),
                child: const Text('Appliquer'),
              ),
            ],
          ),
        );
      },
    );
    if (picked == null) return;
    DateTime? from;
    DateTime? to;
    if (picked.isNotEmpty) {
      from = picked[0];
      to = picked.length > 1 ? picked[1] : null;
    }
    if (from != null && to != null && to.isBefore(from)) {
      final temp = from;
      from = to;
      to = temp;
    }
    ref.read(journalColumnFiltersProvider.notifier).state = filters.copyWith(
      fromDate: from,
      toDate: to,
    );
  }

  Future<void> _pickLabel(
    BuildContext context,
    WidgetRef ref,
    JournalColumnFilters filters,
  ) async {
    final controller = TextEditingController(text: filters.label);
    final next = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text(
          'Filtrer par libelle',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(labelText: 'Libelle contient...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Annuler',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(''),
            child: const Text(
              'Effacer',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Appliquer'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (next == null) return;
    ref.read(journalColumnFiltersProvider.notifier).state = filters.copyWith(
      label: next,
    );
  }

  Future<void> _pickAmount(
    BuildContext context,
    WidgetRef ref,
    JournalColumnFilters filters,
  ) async {
    final minCtrl = TextEditingController(
      text: filters.minAmount?.toStringAsFixed(2) ?? '',
    );
    final maxCtrl = TextEditingController(
      text: filters.maxAmount?.toStringAsFixed(2) ?? '',
    );
    final picked = await showDialog<List<double?>>(
      context: context,
      builder: (dialogContext) {
        String? error;
        return StatefulBuilder(
          builder: (context, setLocalState) => AlertDialog(
            backgroundColor: AppColors.surfaceElevated,
            title: const Text(
              'Filtrer par montant',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: minCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(labelText: 'Montant min'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: maxCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(labelText: 'Montant max'),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(
                  'Annuler',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(<double?>[]),
                child: const Text(
                  'Effacer',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  final min = _parseAmount(minCtrl.text);
                  final max = _parseAmount(maxCtrl.text);
                  final minInvalid =
                      minCtrl.text.trim().isNotEmpty && min == null;
                  final maxInvalid =
                      maxCtrl.text.trim().isNotEmpty && max == null;
                  if (minInvalid || maxInvalid) {
                    setLocalState(() => error = 'Montant invalide');
                    return;
                  }
                  if (min != null && max != null && max < min) {
                    setLocalState(() => error = 'Montant max < montant min');
                    return;
                  }
                  Navigator.of(dialogContext).pop(<double?>[min, max]);
                },
                child: const Text('Appliquer'),
              ),
            ],
          ),
        );
      },
    );
    minCtrl.dispose();
    maxCtrl.dispose();
    if (picked == null) return;
    final min = picked.isNotEmpty ? picked[0] : null;
    final max = picked.length > 1 ? picked[1] : null;
    ref.read(journalColumnFiltersProvider.notifier).state = filters.copyWith(
      minAmount: picked.isEmpty ? null : min,
      maxAmount: picked.isEmpty ? null : max,
    );
  }

  void _clearColumnFilters(WidgetRef ref) {
    ref.read(journalColumnFiltersProvider.notifier).state =
        const JournalColumnFilters();
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  double? _parseAmount(String input) {
    final raw = input.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }
}

class _DateFilterInput extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DateFilterInput({
    required this.label,
    required this.date,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.r10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                date == null ? label : '$label: ${fmt.format(date!)}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (date != null)
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.clear, size: 16),
                color: AppColors.textDisabled,
                splashRadius: 16,
                tooltip: 'Effacer',
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool expand;
  final bool showChevron;

  const _FilterChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.expand = false,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Container(
        width: expand ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          border: Border.all(color: AppColors.borderSubtle),
          borderRadius: BorderRadius.zero,
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            if (expand)
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            if (showChevron) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.expand_more,
                size: 14,
                color: AppColors.textDisabled,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _JournalBody extends ConsumerWidget {
  final List<Transaction> transactions;
  final Transaction? selected;
  final bool isMobile;

  const _JournalBody({
    required this.transactions,
    required this.selected,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageItems = transactions;
    final monthTotals = _buildMonthTotals(transactions);

    return Container(
      color: AppColors.surfaceElevated,
      child: Column(
        children: [
          Expanded(
            child: _TransactionTable(
              transactions: pageItems,
              monthTotals: monthTotals,
              isMobile: isMobile,
              onSelect: (tx) => _onSelect(context, ref, tx, isMobile),
              selectedId: selected?.id,
            ),
          ),
        ],
      ),
    );
  }

  void _onSelect(
    BuildContext context,
    WidgetRef ref,
    Transaction tx,
    bool isMobile,
  ) {
    ref.read(_selectedTxIdProvider.notifier).state = tx.id;
    if (!isMobile) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.86,
        minChildSize: 0.55,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.xxl),
            ),
          ),
          child: SingleChildScrollView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
            child: _DetailView(
              transaction: tx,
              onClose: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
    );
  }
}

Map<int, _MonthTotals> _buildMonthTotals(List<Transaction> transactions) {
  final map = <int, _MonthTotals>{};
  for (final tx in transactions) {
    final key = _monthKey(tx.date);
    final current = map[key] ?? const _MonthTotals();
    if (tx.isIncome) {
      map[key] = current.copyWith(income: current.income + tx.amount.abs());
    } else {
      map[key] = current.copyWith(expense: current.expense + tx.amount.abs());
    }
  }
  return map;
}

int _monthKey(DateTime date) => date.year * 100 + date.month;

class _MonthTotals {
  final double income;
  final double expense;

  const _MonthTotals({this.income = 0, this.expense = 0});

  _MonthTotals copyWith({double? income, double? expense}) => _MonthTotals(
    income: income ?? this.income,
    expense: expense ?? this.expense,
  );
}

class _DesktopDetailOverlay extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback onClose;

  const _DesktopDetailOverlay({
    required this.transaction,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final width = math.min(620.0, MediaQuery.sizeOf(context).width * 0.46);
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            onTap: onClose,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2.8, sigmaY: 2.8),
              child: Container(color: Colors.black.withAlpha(70)),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 1, end: 0),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Transform.translate(
                offset: Offset(80 * value, 0),
                child: Opacity(opacity: 1 - value * 0.25, child: child),
              ),
              child: Container(
                width: width,
                height: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceElevated,
                  border: Border(
                    left: BorderSide(color: AppColors.borderSubtle),
                  ),
                ),
                child: SingleChildScrollView(
                  child: _DetailView(
                    transaction: transaction,
                    onClose: onClose,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTable extends StatelessWidget {
  final List<Transaction> transactions;
  final Map<int, _MonthTotals> monthTotals;
  final bool isMobile;
  final String? selectedId;
  final ValueChanged<Transaction> onSelect;

  const _TransactionTable({
    required this.transactions,
    required this.monthTotals,
    required this.isMobile,
    required this.onSelect,
    required this.selectedId,
  });

  @override
  Widget build(BuildContext context) {
    final rows = _buildRows(transactions);
    return AppPanel(
      padding: EdgeInsets.zero,
      radius: 0,
      variant: AppPanelVariant.surface,
      boxShadow: const [],
      child: Column(
        children: [
          _JournalFilterBar(isMobile: isMobile),
          _TableHeader(isMobile: isMobile),
          const Divider(height: 1, color: AppColors.borderSubtle),
          Expanded(
            child: rows.isEmpty
                ? const Center(
                    child: Text(
                      'Aucune transaction sur ce filtre',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final entry = rows[index];
                      if (entry.monthHeader != null) {
                        final key = _monthKey(entry.monthHeader!);
                        return _MonthHeaderRow(
                          monthDate: entry.monthHeader!,
                          totals: monthTotals[key] ?? const _MonthTotals(),
                          isMobile: isMobile,
                        );
                      }
                      final tx = entry.transaction!;
                      return Column(
                        children: [
                          _TransactionRow(
                            transaction: tx,
                            isMobile: isMobile,
                            selected: tx.id == selectedId,
                            onTap: () => onSelect(tx),
                          ),
                          const Divider(
                            height: 1,
                            color: AppColors.borderSubtle,
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<_TableRowEntry> _buildRows(List<Transaction> txs) {
    final rows = <_TableRowEntry>[];
    int? month;
    int? year;
    for (final tx in txs) {
      if (tx.date.month != month || tx.date.year != year) {
        month = tx.date.month;
        year = tx.date.year;
        rows.add(_TableRowEntry.month(tx.date));
      }
      rows.add(_TableRowEntry.transaction(tx));
    }
    return rows;
  }
}

class _TableRowEntry {
  final DateTime? monthHeader;
  final Transaction? transaction;

  const _TableRowEntry.month(DateTime month)
    : monthHeader = month,
      transaction = null;

  const _TableRowEntry.transaction(Transaction tx)
    : monthHeader = null,
      transaction = tx;
}

class _MonthHeaderRow extends StatelessWidget {
  final DateTime monthDate;
  final _MonthTotals totals;
  final bool isMobile;

  const _MonthHeaderRow({
    required this.monthDate,
    required this.totals,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy', 'fr_FR').format(monthDate);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceHeader,
        border: const Border(
          top: BorderSide(color: AppColors.borderSubtle),
          bottom: BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      child: Row(
        children: [
          Text(
            monthLabel[0].toUpperCase() + monthLabel.substring(1),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 0.4,
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Gagne ${AppFormats.currency.format(totals.income)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Depense ${AppFormats.currency.format(totals.expense)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final bool isMobile;
  const _TableHeader({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.textDisabled,
      letterSpacing: 1.0,
    );
    if (isMobile) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(flex: 4, child: Text('TRANSACTION', style: style)),
            Expanded(
              flex: 2,
              child: Text('MONTANT', style: style, textAlign: TextAlign.end),
            ),
          ],
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('DATE', style: style)),
          Expanded(flex: 4, child: Text('LIBELLE', style: style)),
          Expanded(flex: 3, child: Text('COMPTE', style: style)),
          Expanded(flex: 2, child: Text('STATUT', style: style)),
          Expanded(
            flex: 2,
            child: Text('MONTANT', style: style, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatefulWidget {
  final Transaction transaction;
  final bool isMobile;
  final bool selected;
  final VoidCallback onTap;

  const _TransactionRow({
    required this.transaction,
    required this.isMobile,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_TransactionRow> createState() => _TransactionRowState();
}

class _TransactionRowState extends State<_TransactionRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final transaction = widget.transaction;
    final amountPrefix = transaction.isIncome ? '+' : '-';
    final amountColor = transaction.isIncome
        ? AppColors.primary
        : AppColors.textPrimary;
    final rowBg = widget.selected
        ? AppColors.primary.withAlpha(_hovered ? 22 : 12)
        : (_hovered ? Colors.black.withAlpha(18) : Colors.transparent);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: rowBg,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: widget.isMobile
              ? Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Row(
                        children: [
                          _TransactionAvatar(
                            transaction: transaction,
                            size: 30,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _displayLabel(transaction),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat(
                                    'dd MMM yyyy',
                                    'fr_FR',
                                  ).format(transaction.date),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '$amountPrefix${AppFormats.currency.format(transaction.amount)}',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: amountColor,
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        DateFormat(
                          'dd MMM yyyy',
                          'fr_FR',
                        ).format(transaction.date),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Row(
                        children: [
                          _TransactionAvatar(
                            transaction: transaction,
                            size: 32,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _displayLabel(transaction),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        transaction.accountName ?? '-',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _StatusPill(transaction: transaction),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '$amountPrefix${AppFormats.currency.format(transaction.amount)}',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: amountColor,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

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
      padding: const EdgeInsets.all(20),
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
                chipColor: tx.isAuto
                    ? AppColors.primary
                    : const Color(0xFF2563EB),
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
              padding: const EdgeInsets.all(14),
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
    final label = _statusLabel(transaction);
    final color = transaction.isCompleted
        ? AppColors.primary
        : AppColors.warning;
    final icon = transaction.isCompleted ? Icons.check_circle : Icons.schedule;

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
      color = const Color(0xFF1DB954);
    } else if (label.contains('netflix')) {
      icon = Icons.movie_filter;
      color = const Color(0xFFE50914);
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
  return (tx.accountName ?? tx.accountId).trim();
}

String _statusLabel(Transaction tx) {
  if (tx.isCompleted) return 'Paye';
  if (tx.isAuto) return 'Auto a venir';
  return 'A payer';
}
