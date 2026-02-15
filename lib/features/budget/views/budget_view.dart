import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/features/budget/providers/budget_provider.dart';
import 'package:solver/features/budget/providers/goals_provider.dart';
import 'package:solver/shared/widgets/app_panel.dart';

final _viewModeProvider = StateProvider<bool>(
  (ref) => true,
); // true = cards, false = list

const _monthNames = <String>[
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

class _GroupDraft {
  final String inputMode; // percent | amount
  final double percent;
  final double amount;
  final int priority;

  const _GroupDraft({
    required this.inputMode,
    required this.percent,
    required this.amount,
    required this.priority,
  });

  _GroupDraft copyWith({
    String? inputMode,
    double? percent,
    double? amount,
    int? priority,
  }) {
    return _GroupDraft(
      inputMode: inputMode ?? this.inputMode,
      percent: percent ?? this.percent,
      amount: amount ?? this.amount,
      priority: priority ?? this.priority,
    );
  }
}

class _RenderedGroup {
  final BudgetPlanGroup group;
  final _GroupDraft draft;
  final double plannedPercent;
  final double plannedAmount;

  const _RenderedGroup({
    required this.group,
    required this.draft,
    required this.plannedPercent,
    required this.plannedAmount,
  });
}

class _PlanTotals {
  final double totalPercent;
  final double totalAmount;
  final double remainingPercent;
  final double remainingAmount;

  const _PlanTotals({
    required this.totalPercent,
    required this.totalAmount,
    required this.remainingPercent,
    required this.remainingAmount,
  });

  bool get overLimit => totalPercent > 100.0001;
}

DateTime _monthStart(DateTime d) => DateTime(d.year, d.month, 1);
DateTime _shiftMonth(DateTime d, int delta) =>
    DateTime(d.year, d.month + delta, 1);

double _parseNumber(String raw) =>
    double.tryParse(raw.replaceAll(' ', '').replaceAll(',', '.')) ?? 0.0;

String _statusLabel(String status) {
  switch (status) {
    case 'achieved':
      return 'Atteint';
    case 'on_track':
      return 'Sur trajectoire';
    case 'behind':
      return 'En retard';
    case 'overdue':
      return 'Depasse';
    default:
      return status;
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'achieved':
      return AppColors.primary;
    case 'on_track':
      return const Color(0xFF15803D);
    case 'behind':
      return const Color(0xFFB45309);
    case 'overdue':
      return AppColors.danger;
    default:
      return AppColors.textSecondary;
  }
}

class BudgetView extends ConsumerStatefulWidget {
  const BudgetView({super.key});

  @override
  ConsumerState<BudgetView> createState() => _BudgetViewState();
}

class _BudgetViewState extends ConsumerState<BudgetView> {
  final Map<String, _GroupDraft> _drafts = {};
  String? _draftToken;
  bool _dirty = false;
  bool _savingPlan = false;
  double? _draftDisposableIncome;
  String? _draftError;

  void _syncDraft(BudgetStats stats, {bool force = false}) {
    final token =
        '${stats.selectedYear}-${stats.selectedMonth}-${stats.budgetPlan.id}';
    if (!force && _draftToken == token) return;

    _draftToken = token;
    _draftDisposableIncome = stats.budgetPlan.forecastDisposableIncome;
    _draftError = null;
    _dirty = false;
    _drafts
      ..clear()
      ..addEntries(
        stats.budgetPlan.groups.map(
          (g) => MapEntry(
            g.groupId,
            _GroupDraft(
              inputMode: g.inputMode,
              percent: g.plannedPercent,
              amount: g.plannedAmount,
              priority: g.priority,
            ),
          ),
        ),
      );
  }

  List<_RenderedGroup> _buildRenderedGroups(BudgetStats stats) {
    final disposable =
        (_draftDisposableIncome ?? stats.budgetPlan.forecastDisposableIncome)
            .clamp(0, double.infinity)
            .toDouble();

    final rows = stats.budgetPlan.groups.map((group) {
      final draft =
          _drafts[group.groupId] ??
          _GroupDraft(
            inputMode: group.inputMode,
            percent: group.plannedPercent,
            amount: group.plannedAmount,
            priority: group.priority,
          );

      final plannedPercent = draft.inputMode == 'amount'
          ? (disposable > 0 ? (draft.amount / disposable) * 100 : 0.0)
          : draft.percent;
      final plannedAmount = draft.inputMode == 'amount'
          ? draft.amount
          : disposable * draft.percent / 100;

      return _RenderedGroup(
        group: group,
        draft: draft,
        plannedPercent: plannedPercent.clamp(0, double.infinity),
        plannedAmount: plannedAmount.clamp(0, double.infinity),
      );
    }).toList();

    rows.sort((a, b) {
      final p = a.draft.priority.compareTo(b.draft.priority);
      if (p != 0) return p;
      return a.group.sortOrder.compareTo(b.group.sortOrder);
    });
    return rows;
  }

  _PlanTotals _computeTotals(List<_RenderedGroup> rows, double disposable) {
    final totalPercent = rows.fold<double>(
      0.0,
      (sum, r) => sum + r.plannedPercent,
    );
    final totalAmount = rows.fold<double>(
      0.0,
      (sum, r) => sum + r.plannedAmount,
    );
    final remainingPercent = 100 - totalPercent;
    final remainingAmount = disposable - totalAmount;
    return _PlanTotals(
      totalPercent: totalPercent,
      totalAmount: totalAmount,
      remainingPercent: remainingPercent,
      remainingAmount: remainingAmount,
    );
  }

  void _setGroupMode(_RenderedGroup row, String mode) {
    final current = _drafts[row.group.groupId]!;
    if (current.inputMode == mode) return;
    setState(() {
      _dirty = true;
      _draftError = null;
      _drafts[row.group.groupId] = current.copyWith(
        inputMode: mode,
        percent: row.plannedPercent,
        amount: row.plannedAmount,
      );
    });
  }

  void _setGroupValue(_RenderedGroup row, String rawValue) {
    final value = _parseNumber(rawValue).clamp(0, double.infinity).toDouble();
    final current = _drafts[row.group.groupId]!;
    setState(() {
      _dirty = true;
      _draftError = null;
      if (current.inputMode == 'amount') {
        _drafts[row.group.groupId] = current.copyWith(amount: value);
      } else {
        _drafts[row.group.groupId] = current.copyWith(percent: value);
      }
    });
  }

  Future<void> _savePlan(BudgetStats stats, _PlanTotals totals) async {
    if (totals.overLimit) {
      setState(() {
        _draftError = 'Le total depasse 100%.';
      });
      return;
    }
    setState(() {
      _savingPlan = true;
      _draftError = null;
    });
    try {
      final month = _monthStart(ref.read(selectedBudgetMonthProvider));
      final rows = _buildRenderedGroups(stats);
      final api = ref.read(budgetPlanApiProvider);
      await api.upsertPlan(
        year: month.year,
        month: month.month,
        forecastDisposableIncome:
            (_draftDisposableIncome ??
                    stats.budgetPlan.forecastDisposableIncome)
                .toDouble(),
        groups: rows
            .map(
              (r) => BudgetPlanGroupUpdate(
                groupId: r.group.groupId,
                inputMode: r.draft.inputMode,
                plannedPercent: r.plannedPercent,
                plannedAmount: r.plannedAmount,
                priority: r.draft.priority,
              ),
            )
            .toList(),
      );

      ref.invalidate(
        budgetStatsProvider(
          BudgetMonthKey(year: month.year, month: month.month),
        ),
      );
      setState(() {
        _dirty = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Plan budget enregistre')));
      }
    } catch (_) {
      setState(() {
        _draftError = 'Erreur de sauvegarde du plan.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingPlan = false;
        });
      }
    }
  }

  Future<void> _changeMonth(int delta) async {
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Modifier le mois'),
          content: const Text(
            'Des changements non sauvegardes seront perdus. Continuer ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continuer'),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }

    final month = ref.read(selectedBudgetMonthProvider);
    ref.read(selectedBudgetMonthProvider.notifier).state = _monthStart(
      _shiftMonth(month, delta),
    );
  }

  Future<void> _showGoalEditor({SavingGoal? goal}) async {
    final nameCtrl = TextEditingController(text: goal?.name ?? '');
    final targetCtrl = TextEditingController(
      text: goal == null ? '' : goal.targetAmount.toStringAsFixed(0),
    );
    final initialCtrl = TextEditingController(
      text: goal == null ? '0' : goal.initialAmount.toStringAsFixed(0),
    );
    final monthlyCtrl = TextEditingController(
      text: goal == null ? '0' : goal.monthlyContribution.toStringAsFixed(0),
    );
    final priorityCtrl = TextEditingController(
      text: goal == null ? '0' : goal.priority.toString(),
    );
    DateTime targetDate =
        goal?.targetDate ?? DateTime.now().add(const Duration(days: 365));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(goal == null ? 'Nouvel objectif' : 'Modifier objectif'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nom'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: targetCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Montant cible (${AppFormats.currencyCode})',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: initialCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Montant initial (${AppFormats.currencyCode})',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: monthlyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
                    ],
                    decoration: InputDecoration(
                      labelText:
                          'Contribution mensuelle (${AppFormats.currencyCode})',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: priorityCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Priorite (0 = plus prioritaire)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        'Date cible',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: targetDate,
                            firstDate: DateTime(2020, 1, 1),
                            lastDate: DateTime(2100, 12, 31),
                          );
                          if (picked != null) {
                            setLocalState(() => targetDate = picked);
                          }
                        },
                        child: Text(
                          '${targetDate.day.toString().padLeft(2, '0')}.${targetDate.month.toString().padLeft(2, '0')}.${targetDate.year}',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sauvegarder'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      final api = ref.read(goalsApiProvider);
      if (goal == null) {
        await api.createGoal(
          name: nameCtrl.text.trim(),
          targetAmount: _parseNumber(targetCtrl.text),
          targetDate: targetDate,
          initialAmount: _parseNumber(initialCtrl.text),
          monthlyContribution: _parseNumber(monthlyCtrl.text),
          priority: int.tryParse(priorityCtrl.text),
        );
      } else {
        await api.updateGoal(
          id: goal.id,
          name: nameCtrl.text.trim(),
          targetAmount: _parseNumber(targetCtrl.text),
          targetDate: targetDate,
          initialAmount: _parseNumber(initialCtrl.text),
          monthlyContribution: _parseNumber(monthlyCtrl.text),
          priority: int.tryParse(priorityCtrl.text) ?? goal.priority,
        );
      }
      ref.invalidate(goalsProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Objectif enregistre')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur de sauvegarde objectif')),
        );
      }
    }
  }

  Future<void> _showGoalEntryEditor(SavingGoal goal) async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    var isDeposit = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text('Mouvement - ${goal.name}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Depot'),
                        selected: isDeposit,
                        onSelected: (_) =>
                            setLocalState(() => isDeposit = true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Retrait'),
                        selected: !isDeposit,
                        onSelected: (_) =>
                            setLocalState(() => isDeposit = false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Montant (${AppFormats.currencyCode})',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
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
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      final amount = _parseNumber(amountCtrl.text);
      if (amount <= 0) return;
      final signed = isDeposit ? amount : -amount;
      await ref
          .read(goalsApiProvider)
          .addEntry(
            goalId: goal.id,
            amount: signed,
            note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
          );
      ref.invalidate(goalsProvider);
      ref.invalidate(goalEntriesProvider(goal.id));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Mouvement enregistre')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Erreur de mouvement')));
      }
    }
  }

  Future<void> _showGoalHistory(SavingGoal goal) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: SizedBox(
          width: 720,
          height: 520,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Historique - ${goal.name}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Fermer'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final asyncEntries = ref.watch(
                        goalEntriesProvider(goal.id),
                      );
                      return asyncEntries.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text('Erreur: $e')),
                        data: (entries) {
                          if (entries.isEmpty) {
                            return const Center(
                              child: Text('Aucun mouvement pour cet objectif.'),
                            );
                          }
                          return ListView.separated(
                            itemCount: entries.length,
                            separatorBuilder: (_, i) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final entry = entries[index];
                              final isPositive = entry.amount >= 0;
                              return ListTile(
                                dense: true,
                                title: Text(
                                  '${entry.entryDate.day.toString().padLeft(2, '0')}.${entry.entryDate.month.toString().padLeft(2, '0')}.${entry.entryDate.year}',
                                ),
                                subtitle: Text(
                                  entry.note ??
                                      (entry.isAuto ? 'Auto' : 'Manuel'),
                                ),
                                trailing: Text(
                                  '${isPositive ? '+' : '-'} ${AppFormats.currencyCompact.format(entry.amount.abs())}',
                                  style: TextStyle(
                                    color: isPositive
                                        ? AppColors.primary
                                        : AppColors.danger,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedMonth = ref.watch(selectedBudgetMonthProvider);
    final monthKey = BudgetMonthKey(
      year: selectedMonth.year,
      month: selectedMonth.month,
    );
    final statsAsync = ref.watch(budgetStatsProvider(monthKey));
    final goalsAsync = ref.watch(goalsProvider);
    final isCards = ref.watch(_viewModeProvider);

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Erreur budget: $e',
          style: const TextStyle(color: AppColors.danger),
        ),
      ),
      data: (stats) {
        _syncDraft(stats);
        final disposable =
            (_draftDisposableIncome ??
                    stats.budgetPlan.forecastDisposableIncome)
                .clamp(0, double.infinity);
        final rows = _buildRenderedGroups(stats);
        final totals = _computeTotals(rows, disposable.toDouble());

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1380),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PlannerTopBar(
                    selectedMonth: selectedMonth,
                    dirty: _dirty,
                    saving: _savingPlan,
                    onPrevMonth: () => _changeMonth(-1),
                    onNextMonth: () => _changeMonth(1),
                    onSave: totals.overLimit
                        ? null
                        : () => _savePlan(stats, totals),
                    onReset: () =>
                        setState(() => _syncDraft(stats, force: true)),
                  ),
                  const SizedBox(height: 12),
                  _PlannerHero(
                    disposable: disposable.toDouble(),
                    totalPercent: totals.totalPercent,
                    totalAmount: totals.totalAmount,
                    remainingPercent: totals.remainingPercent,
                    remainingAmount: totals.remainingAmount,
                    averageIncome: stats.averageIncome,
                    fixedExpenses: stats.fixedExpensesTotal,
                    copiedFrom: stats.budgetPlan.copiedFrom,
                    onDisposableChanged: (raw) {
                      setState(() {
                        _dirty = true;
                        _draftError = null;
                        _draftDisposableIncome = _parseNumber(
                          raw,
                        ).clamp(0, double.infinity).toDouble();
                      });
                    },
                  ),
                  if (_draftError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _draftError!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        'ALLOCATION PAR GROUPE (${rows.length})',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDisabled,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(AppRadius.r12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ToggleButton(
                              icon: Icons.grid_view_rounded,
                              isActive: isCards,
                              onTap: () =>
                                  ref.read(_viewModeProvider.notifier).state =
                                      true,
                            ),
                            _ToggleButton(
                              icon: Icons.format_list_bulleted,
                              isActive: !isCards,
                              onTap: () =>
                                  ref.read(_viewModeProvider.notifier).state =
                                      false,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        totals.overLimit
                            ? 'Depassement du total 100%'
                            : 'Total allocation OK',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: totals.overLimit
                              ? AppColors.danger
                              : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (isCards)
                    _CardsLayout(
                      rows: rows,
                      onModeChanged: _setGroupMode,
                      onValueChanged: _setGroupValue,
                    )
                  else
                    _ListLayout(
                      rows: rows,
                      onModeChanged: _setGroupMode,
                      onValueChanged: _setGroupValue,
                    ),
                  const SizedBox(height: 24),
                  _GoalsSection(
                    goalsAsync: goalsAsync,
                    onCreateGoal: () => _showGoalEditor(),
                    onEditGoal: (goal) => _showGoalEditor(goal: goal),
                    onAddEntry: _showGoalEntryEditor,
                    onHistory: _showGoalHistory,
                    onArchive: (goal) async {
                      await ref
                          .read(goalsApiProvider)
                          .archiveGoal(
                            id: goal.id,
                            isArchived: !goal.isArchived,
                          );
                      ref.invalidate(goalsProvider);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlannerTopBar extends StatelessWidget {
  final DateTime selectedMonth;
  final bool dirty;
  final bool saving;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final VoidCallback? onSave;
  final VoidCallback onReset;

  const _PlannerTopBar({
    required this.selectedMonth,
    required this.dirty,
    required this.saving,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onSave,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onPrevMonth,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Text(
          '${_monthNames[selectedMonth.month - 1]} ${selectedMonth.year}',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        IconButton(
          onPressed: onNextMonth,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        const Spacer(),
        if (dirty)
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Text(
              'Modifications non sauvegardees',
              style: TextStyle(
                color: Color(0xFFB45309),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        OutlinedButton(onPressed: onReset, child: const Text('Recharger')),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: saving ? null : onSave,
          icon: saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined, size: 18),
          label: Text(saving ? 'Sauvegarde...' : 'Sauvegarder le plan'),
        ),
      ],
    );
  }
}

class _PlannerHero extends StatelessWidget {
  final double disposable;
  final double totalPercent;
  final double totalAmount;
  final double remainingPercent;
  final double remainingAmount;
  final double averageIncome;
  final double fixedExpenses;
  final BudgetPlanCopySource? copiedFrom;
  final ValueChanged<String> onDisposableChanged;

  const _PlannerHero({
    required this.disposable,
    required this.totalPercent,
    required this.totalAmount,
    required this.remainingPercent,
    required this.remainingAmount,
    required this.averageIncome,
    required this.fixedExpenses,
    required this.copiedFrom,
    required this.onDisposableChanged,
  });

  @override
  Widget build(BuildContext context) {
    final overLimit = totalPercent > 100.0001;
    final ratio = (totalPercent / 100).clamp(0.0, 1.0);

    return AppPanel(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      radius: AppRadius.r20,
      borderColor: AppColors.borderSubtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Revenu disponible du mois',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 220,
                child: TextFormField(
                  key: ValueKey('disposable-${disposable.toStringAsFixed(2)}'),
                  initialValue: disposable.toStringAsFixed(0),
                  onChanged: onDisposableChanged,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
                  ],
                  decoration: InputDecoration(
                    prefixText: '${AppFormats.currencySymbol} ',
                    hintText: '0',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'Base moyenne: ${AppFormats.currencyCompact.format(averageIncome)} - fixes ${AppFormats.currencyCompact.format(fixedExpenses)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (copiedFrom != null)
                Text(
                  'Plan recopie de ${_monthNames[copiedFrom!.month - 1]} ${copiedFrom!.year}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '${totalPercent.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: overLimit ? AppColors.danger : AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'alloue',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 20),
              Text(
                '${remainingPercent >= 0 ? remainingPercent.toStringAsFixed(1) : '0.0'}% restant',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '- ${AppFormats.currencyCompact.format(totalAmount)} alloue',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${remainingAmount >= 0 ? AppFormats.currencyCompact.format(remainingAmount) : '0'} restant',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: remainingAmount >= 0
                      ? AppColors.primary
                      : AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.r8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(
                overLimit ? AppColors.danger : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardsLayout extends StatelessWidget {
  final List<_RenderedGroup> rows;
  final void Function(_RenderedGroup row, String mode) onModeChanged;
  final void Function(_RenderedGroup row, String value) onValueChanged;

  const _CardsLayout({
    required this.rows,
    required this.onModeChanged,
    required this.onValueChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth > 1180 ? 2 : 1;
        const spacing = 14.0;
        final width = (c.maxWidth - (columns - 1) * spacing) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final row in rows)
              SizedBox(
                width: width,
                child: _GroupCard(
                  row: row,
                  onModeChanged: onModeChanged,
                  onValueChanged: onValueChanged,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ListLayout extends StatelessWidget {
  final List<_RenderedGroup> rows;
  final void Function(_RenderedGroup row, String mode) onModeChanged;
  final void Function(_RenderedGroup row, String value) onValueChanged;

  const _ListLayout({
    required this.rows,
    required this.onModeChanged,
    required this.onValueChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < rows.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == rows.length - 1 ? 0 : 10),
            child: _GroupCard(
              row: rows[i],
              compact: true,
              onModeChanged: onModeChanged,
              onValueChanged: onValueChanged,
            ),
          ),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  final _RenderedGroup row;
  final bool compact;
  final void Function(_RenderedGroup row, String mode) onModeChanged;
  final void Function(_RenderedGroup row, String value) onValueChanged;

  const _GroupCard({
    required this.row,
    required this.onModeChanged,
    required this.onValueChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final usagePct = row.group.spentActual > 0 && row.plannedAmount > 0
        ? (row.group.spentActual / row.plannedAmount) * 100
        : 0.0;
    final cappedUsage = usagePct.clamp(0, 100);

    return AppPanel(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 16,
        vertical: compact ? 12 : 14,
      ),
      radius: AppRadius.r16,
      borderColor: AppColors.borderSubtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.group.groupName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '- ${AppFormats.currencyCompact.format(row.group.spentActual)} reel',
                style: const TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${row.group.categories.length} categories • ${row.group.isFixedGroup ? 'Fixe' : 'Variable/Mixte'}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ChoiceChip(
                label: const Text('%'),
                selected: row.draft.inputMode == 'percent',
                onSelected: (_) => onModeChanged(row, 'percent'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Montant'),
                selected: row.draft.inputMode == 'amount',
                onSelected: (_) => onModeChanged(row, 'amount'),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 140,
                child: TextFormField(
                  key: ValueKey(
                    '${row.group.groupId}-${row.draft.inputMode}-${row.draft.inputMode == 'amount' ? row.plannedAmount.toStringAsFixed(2) : row.plannedPercent.toStringAsFixed(2)}',
                  ),
                  initialValue: row.draft.inputMode == 'amount'
                      ? row.plannedAmount.toStringAsFixed(0)
                      : row.plannedPercent.toStringAsFixed(1),
                  onChanged: (v) => onValueChanged(row, v),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
                  ],
                  decoration: InputDecoration(
                    isDense: true,
                    suffixText: row.draft.inputMode == 'amount'
                        ? AppFormats.currencyCode
                        : '%',
                  ),
                ),
              ),
              const Spacer(),
              Text(
                row.draft.inputMode == 'amount'
                    ? '${row.plannedPercent.toStringAsFixed(1)}%'
                    : AppFormats.currencyCompact.format(row.plannedAmount),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Consomme: ${cappedUsage.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: usagePct >= 100
                      ? AppColors.danger
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                'Prevu: - ${AppFormats.currencyCompact.format(row.plannedAmount)}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.r8),
            child: LinearProgressIndicator(
              value: (cappedUsage / 100).toDouble(),
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(
                usagePct >= 100 ? AppColors.danger : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalsSection extends StatelessWidget {
  final AsyncValue<List<SavingGoal>> goalsAsync;
  final VoidCallback onCreateGoal;
  final void Function(SavingGoal goal) onEditGoal;
  final void Function(SavingGoal goal) onAddEntry;
  final void Function(SavingGoal goal) onHistory;
  final void Function(SavingGoal goal) onArchive;

  const _GoalsSection({
    required this.goalsAsync,
    required this.onCreateGoal,
    required this.onEditGoal,
    required this.onAddEntry,
    required this.onHistory,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      radius: AppRadius.r20,
      borderColor: AppColors.borderSubtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'OBJECTIFS D EPARGNE',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDisabled,
                  fontSize: 11,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: onCreateGoal,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nouvel objectif'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          goalsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text(
              'Erreur objectifs: $e',
              style: const TextStyle(color: AppColors.danger),
            ),
            data: (goals) {
              if (goals.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Aucun objectif pour le moment.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (int i = 0; i < goals.length; i++)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: i == goals.length - 1 ? 0 : 10,
                      ),
                      child: _GoalCard(
                        goal: goals[i],
                        onEdit: () => onEditGoal(goals[i]),
                        onMove: () => onAddEntry(goals[i]),
                        onHistory: () => onHistory(goals[i]),
                        onArchive: () => onArchive(goals[i]),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final SavingGoal goal;
  final VoidCallback onEdit;
  final VoidCallback onMove;
  final VoidCallback onHistory;
  final VoidCallback onArchive;

  const _GoalCard({
    required this.goal,
    required this.onEdit,
    required this.onMove,
    required this.onHistory,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(goal.status);
    final progress = (goal.progressPercent / 100).clamp(0.0, 1.0);
    final projected = goal.projectedDate;

    return AppPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: AppRadius.r16,
      borderColor: AppColors.borderSubtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  goal.name,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(AppRadius.r8),
                ),
                child: Text(
                  _statusLabel(goal.status),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${goal.progressPercent.toStringAsFixed(1)}% - ${AppFormats.currencyCompact.format(goal.currentAmount)} / ${AppFormats.currencyCompact.format(goal.targetAmount)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                'Reste ${AppFormats.currencyCompact.format(goal.remainingAmount)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.r8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              Text(
                'Mensuel actuel: ${AppFormats.currencyCompact.format(goal.monthlyContribution)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                'Mensuel recommande: ${AppFormats.currencyCompact.format(goal.recommendedMonthly)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Mois restants: ${goal.monthsRemaining}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                projected == null
                    ? 'Projection: non calculee'
                    : 'Projection: ${projected.month.toString().padLeft(2, '0')}.${projected.year}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton(
                onPressed: onMove,
                child: const Text('Depot/Retrait'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onHistory,
                child: const Text('Historique'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: onEdit, child: const Text('Modifier')),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onArchive,
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: Text(goal.isArchived ? 'Desarchiver' : 'Archiver'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.r10),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(12),
                    blurRadius: 5,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 19,
          color: isActive ? AppColors.primary : AppColors.textDisabled,
        ),
      ),
    );
  }
}
