import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/features/budget/providers/budget_provider.dart';
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
  final double minAllowedPercent;
  final double minAllowedAmount;
  final double maxAllowedPercent;
  final double maxAllowedAmount;

  const _RenderedGroup({
    required this.group,
    required this.draft,
    required this.plannedPercent,
    required this.plannedAmount,
    required this.minAllowedPercent,
    required this.minAllowedAmount,
    required this.maxAllowedPercent,
    required this.maxAllowedAmount,
  });
}

class _PlanTotals {
  final double manualPercent;
  final double manualAmount;
  final double manualCapacityPercent;
  final double manualCapacityAmount;
  final double autoPercent;
  final double autoAmount;
  final double totalPercent;
  final double totalAmount;
  final double remainingPercent;
  final double remainingAmount;

  const _PlanTotals({
    required this.manualPercent,
    required this.manualAmount,
    required this.manualCapacityPercent,
    required this.manualCapacityAmount,
    required this.autoPercent,
    required this.autoAmount,
    required this.totalPercent,
    required this.totalAmount,
    required this.remainingPercent,
    required this.remainingAmount,
  });

  bool get overLimit => manualPercent > manualCapacityPercent + 0.0001;
}

DateTime _monthStart(DateTime d) => DateTime(d.year, d.month, 1);
DateTime _shiftMonth(DateTime d, int delta) =>
    DateTime(d.year, d.month + delta, 1);

double _parseNumber(String raw) =>
    double.tryParse(raw.replaceAll(' ', '').replaceAll(',', '.')) ?? 0.0;

String _editableInputValue(double value, {int maxDecimals = 1}) {
  if (value.abs() < 0.000001) return '';
  final text = value.toStringAsFixed(maxDecimals);
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}

bool _isFixedLikeGroup(BudgetPlanGroup g) {
  final n = g.groupName.toLowerCase();
  return g.isFixedGroup || (n.contains('charge') && n.contains('fix'));
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
    final autoReserveAmount = stats.budgetPlan.autoReserveAmount
        .clamp(0, double.infinity)
        .toDouble();
    final manualCapacityAmount = (disposable - autoReserveAmount)
        .clamp(0, double.infinity)
        .toDouble();
    final manualCapacityPercent = disposable > 0
        ? (manualCapacityAmount / disposable) * 100
        : 0.0;

    final baseRows = stats.budgetPlan.groups
        .where((g) => !_isFixedLikeGroup(g))
        .map((group) {
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
            minAllowedPercent: 0,
            minAllowedAmount: 0,
            maxAllowedPercent: 100,
            maxAllowedAmount: disposable,
          );
        })
        .toList();

    final totalPercent = baseRows.fold<double>(
      0.0,
      (sum, r) => sum + r.plannedPercent,
    );
    final totalAmount = baseRows.fold<double>(
      0.0,
      (sum, r) => sum + r.plannedAmount,
    );

    final rows = baseRows
        .map(
          (row) => _RenderedGroup(
            group: row.group,
            draft: row.draft,
            plannedPercent: row.plannedPercent,
            plannedAmount: row.plannedAmount,
            minAllowedPercent: row.minAllowedPercent,
            minAllowedAmount: row.minAllowedAmount,
            maxAllowedPercent:
                (manualCapacityPercent - (totalPercent - row.plannedPercent))
                    .clamp(0, 100)
                    .toDouble(),
            maxAllowedAmount:
                (manualCapacityAmount - (totalAmount - row.plannedAmount))
                    .clamp(0, double.infinity)
                    .toDouble(),
          ),
        )
        .toList();

    rows.sort((a, b) {
      final p = a.draft.priority.compareTo(b.draft.priority);
      if (p != 0) return p;
      return a.group.sortOrder.compareTo(b.group.sortOrder);
    });
    return rows;
  }

  _PlanTotals _computeTotals(
    List<_RenderedGroup> rows,
    double disposable,
    double autoReserveAmount,
  ) {
    final manualPercent = rows.fold<double>(
      0.0,
      (sum, r) => sum + r.plannedPercent,
    );
    final manualAmount = rows.fold<double>(
      0.0,
      (sum, r) => sum + r.plannedAmount,
    );
    final safeAutoAmount = autoReserveAmount
        .clamp(0, double.infinity)
        .toDouble();
    final autoPercent = disposable > 0
        ? (safeAutoAmount / disposable) * 100
        : 0.0;
    final manualCapacityAmount = (disposable - safeAutoAmount)
        .clamp(0, double.infinity)
        .toDouble();
    final manualCapacityPercent = disposable > 0
        ? (manualCapacityAmount / disposable) * 100
        : 0.0;
    final totalPercent = manualPercent + autoPercent;
    final totalAmount = manualAmount + safeAutoAmount;
    final remainingPercent = 100 - totalPercent;
    final remainingAmount = disposable - totalAmount;
    return _PlanTotals(
      manualPercent: manualPercent,
      manualAmount: manualAmount,
      manualCapacityPercent: manualCapacityPercent,
      manualCapacityAmount: manualCapacityAmount,
      autoPercent: autoPercent,
      autoAmount: safeAutoAmount,
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
        final clamped = value
            .clamp(row.minAllowedAmount, row.maxAllowedAmount)
            .toDouble();
        _drafts[row.group.groupId] = current.copyWith(amount: clamped);
        if (value > clamped + 0.0001 || value + 0.0001 < clamped) {
          _draftError =
              'Plage autorisee pour ${row.group.groupName}: ${AppFormats.currencyCompact.format(row.minAllowedAmount)} - ${AppFormats.currencyCompact.format(row.maxAllowedAmount)}';
        }
      } else {
        final clamped = value
            .clamp(row.minAllowedPercent, row.maxAllowedPercent)
            .toDouble();
        _drafts[row.group.groupId] = current.copyWith(percent: clamped);
        if (value > clamped + 0.0001 || value + 0.0001 < clamped) {
          _draftError =
              'Plage autorisee pour ${row.group.groupName}: ${row.minAllowedPercent.toStringAsFixed(1)}% - ${row.maxAllowedPercent.toStringAsFixed(1)}%';
        }
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

  @override
  Widget build(BuildContext context) {
    final selectedMonth = ref.watch(selectedBudgetMonthProvider);
    final monthKey = BudgetMonthKey(
      year: selectedMonth.year,
      month: selectedMonth.month,
    );
    final statsAsync = ref.watch(budgetStatsProvider(monthKey));
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
        final totals = _computeTotals(
          rows,
          disposable.toDouble(),
          stats.budgetPlan.autoReserveAmount,
        );
        final autoByGroups = [...stats.budgetPlan.groups]
          ..removeWhere((g) => g.autoPlannedAmount <= 0)
          ..sort((a, b) => b.autoPlannedAmount.compareTo(a.autoPlannedAmount));

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
                    inputVersion:
                        _draftToken ??
                        '${stats.selectedYear}-${stats.selectedMonth}',
                    disposable: disposable.toDouble(),
                    manualPercent: totals.manualPercent,
                    manualAmount: totals.manualAmount,
                    manualCapacityPercent: totals.manualCapacityPercent,
                    manualCapacityAmount: totals.manualCapacityAmount,
                    autoPercent: totals.autoPercent,
                    autoAmount: totals.autoAmount,
                    totalPercent: totals.totalPercent,
                    totalAmount: totals.totalAmount,
                    remainingPercent: totals.remainingPercent,
                    remainingAmount: totals.remainingAmount,
                    averageIncome: stats.averageIncome,
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
                  if (totals.autoAmount > 0) ...[
                    const SizedBox(height: 10),
                    _AutoReserveCard(
                      autoAmount: totals.autoAmount,
                      autoPercent: totals.autoPercent,
                      groups: autoByGroups,
                    ),
                  ],
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
                            ? 'Allocation manuelle depasse la capacite restante'
                            : 'Manuel: ${totals.manualPercent.toStringAsFixed(1)}% / ${totals.manualCapacityPercent.toStringAsFixed(1)}%',
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
                      inputVersion:
                          _draftToken ??
                          '${stats.selectedYear}-${stats.selectedMonth}',
                      rows: rows,
                      onModeChanged: _setGroupMode,
                      onValueChanged: _setGroupValue,
                    )
                  else
                    _ListLayout(
                      inputVersion:
                          _draftToken ??
                          '${stats.selectedYear}-${stats.selectedMonth}',
                      rows: rows,
                      onModeChanged: _setGroupMode,
                      onValueChanged: _setGroupValue,
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
  final String inputVersion;
  final double disposable;
  final double manualPercent;
  final double manualAmount;
  final double manualCapacityPercent;
  final double manualCapacityAmount;
  final double autoPercent;
  final double autoAmount;
  final double totalPercent;
  final double totalAmount;
  final double remainingPercent;
  final double remainingAmount;
  final double averageIncome;
  final BudgetPlanCopySource? copiedFrom;
  final ValueChanged<String> onDisposableChanged;

  const _PlannerHero({
    required this.inputVersion,
    required this.disposable,
    required this.manualPercent,
    required this.manualAmount,
    required this.manualCapacityPercent,
    required this.manualCapacityAmount,
    required this.autoPercent,
    required this.autoAmount,
    required this.totalPercent,
    required this.totalAmount,
    required this.remainingPercent,
    required this.remainingAmount,
    required this.averageIncome,
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
                  key: ValueKey('disposable-$inputVersion'),
                  initialValue: _editableInputValue(disposable, maxDecimals: 0),
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
                'Base moyenne 3 mois: ${AppFormats.currencyCompact.format(averageIncome)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (autoAmount > 0) ...[
                const SizedBox(width: 12),
                Text(
                  'Prelevements auto reserves: ${AppFormats.currencyCompact.format(autoAmount)} (${autoPercent.toStringAsFixed(1)}%)',
                  style: TextStyle(
                    fontSize: 12,
                    color: autoPercent > 100
                        ? AppColors.danger
                        : AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
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
                'Manuel ${manualPercent.toStringAsFixed(1)}% / ${manualCapacityPercent.toStringAsFixed(1)}%',
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
          const SizedBox(height: 6),
          Text(
            'Capacite manuelle: ${AppFormats.currencyCompact.format(manualCapacityAmount)} - alloue manuel: ${AppFormats.currencyCompact.format(manualAmount)}'
            '${remainingPercent < 0 ? ' - deficit global' : ''}',
            style: TextStyle(
              fontSize: 12,
              color: remainingPercent < 0
                  ? AppColors.danger
                  : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
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

class _AutoReserveCard extends StatelessWidget {
  final double autoAmount;
  final double autoPercent;
  final List<BudgetPlanGroup> groups;

  const _AutoReserveCard({
    required this.autoAmount,
    required this.autoPercent,
    required this.groups,
  });

  @override
  Widget build(BuildContext context) {
    final visible = groups.take(6).toList();
    final remaining = groups.length - visible.length;

    return AppPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      radius: AppRadius.r16,
      borderColor: const Color(0xFFE7EFE1),
      backgroundColor: const Color(0xFFF9FCF7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bolt_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Prelevements automatiques (reserves)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${AppFormats.currencyCompact.format(autoAmount)} - ${autoPercent.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Ces montants sont exclus des cartes manuelles pour eviter les doublons.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          if (visible.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in visible)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.r10),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Text(
                      '${g.groupName}: ${AppFormats.currencyCompact.format(g.autoPlannedAmount)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                if (remaining > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.r10),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Text(
                      '+$remaining autres',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
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

class _CardsLayout extends StatelessWidget {
  final String inputVersion;
  final List<_RenderedGroup> rows;
  final void Function(_RenderedGroup row, String mode) onModeChanged;
  final void Function(_RenderedGroup row, String value) onValueChanged;

  const _CardsLayout({
    required this.inputVersion,
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
                  inputVersion: inputVersion,
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
  final String inputVersion;
  final List<_RenderedGroup> rows;
  final void Function(_RenderedGroup row, String mode) onModeChanged;
  final void Function(_RenderedGroup row, String value) onValueChanged;

  const _ListLayout({
    required this.inputVersion,
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
              inputVersion: inputVersion,
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
  final String inputVersion;
  final _RenderedGroup row;
  final bool compact;
  final void Function(_RenderedGroup row, String mode) onModeChanged;
  final void Function(_RenderedGroup row, String value) onValueChanged;

  const _GroupCard({
    required this.inputVersion,
    required this.row,
    required this.onModeChanged,
    required this.onValueChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final usagePct = row.plannedAmount > 0
        ? (row.group.spentActual / row.plannedAmount) * 100
        : (row.group.spentActual > 0 ? 999.0 : 0.0);
    final overUsage = usagePct > 100;
    final progressBarValue = (usagePct / 100).clamp(0, 1);
    final sliderMin = row.draft.inputMode == 'amount'
        ? row.minAllowedAmount
        : row.minAllowedPercent;
    final sliderMax = row.draft.inputMode == 'amount'
        ? row.maxAllowedAmount
        : row.maxAllowedPercent;
    final safeSliderMin = sliderMin.toDouble();
    final safeSliderMax =
        (sliderMax <= safeSliderMin ? safeSliderMin + 0.0001 : sliderMax)
            .toDouble();
    final sliderValue =
        (row.draft.inputMode == 'amount'
                ? row.plannedAmount
                : row.plannedPercent)
            .clamp(safeSliderMin, safeSliderMax);

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
                'Depense reelle: ${AppFormats.currencyCompact.format(row.group.spentActual)}',
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
            '${row.group.categories.length} categories - ${row.group.isFixedGroup ? 'Fixe' : 'Variable/Mixte'}',
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
                    '$inputVersion-${row.group.groupId}-${row.draft.inputMode}',
                  ),
                  initialValue: row.draft.inputMode == 'amount'
                      ? _editableInputValue(row.plannedAmount, maxDecimals: 0)
                      : _editableInputValue(row.plannedPercent, maxDecimals: 1),
                  onChanged: (v) => onValueChanged(row, v),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
                  ],
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '0',
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
          const SizedBox(height: 2),
          Slider(
            value: sliderValue.toDouble(),
            min: safeSliderMin,
            max: safeSliderMax,
            onChanged: (value) {
              onValueChanged(
                row,
                row.draft.inputMode == 'amount'
                    ? value.toStringAsFixed(0)
                    : value.toStringAsFixed(1),
              );
            },
          ),
          Row(
            children: [
              Text(
                row.draft.inputMode == 'amount'
                    ? AppFormats.currencyCompact.format(row.minAllowedAmount)
                    : '${row.minAllowedPercent.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textDisabled,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                row.draft.inputMode == 'amount'
                    ? AppFormats.currencyCompact.format(safeSliderMax)
                    : '${row.maxAllowedPercent.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textDisabled,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                row.plannedAmount <= 0
                    ? (row.group.spentActual > 0
                          ? 'Utilise: depense sans enveloppe'
                          : 'Utilise: 0%')
                    : 'Utilise: ${usagePct.toStringAsFixed(0)}%',
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
                usagePct > 100 && row.plannedAmount > 0
                    ? 'Depasse de ${AppFormats.currencyCompact.format(row.group.spentActual - row.plannedAmount)}'
                    : 'Planifie: ${AppFormats.currencyCompact.format(row.plannedAmount)}',
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
              value: progressBarValue.toDouble(),
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(
                overUsage ? AppColors.danger : AppColors.primary,
              ),
            ),
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
