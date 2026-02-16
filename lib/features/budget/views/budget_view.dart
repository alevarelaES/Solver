import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
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
  if (maxDecimals <= 0) {
    return value.toStringAsFixed(0);
  }
  final text = value.toStringAsFixed(maxDecimals);
  if (!text.contains('.')) return text;
  return text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
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
  bool _useGrossIncomeBase = false;
  double? _draftDisposableIncome;
  String? _draftError;

  double _manualCommittedAmount(BudgetStats stats) =>
      stats.budgetPlan.committedManualAmount;

  double _totalCommittedAmount(BudgetStats stats) =>
      stats.budgetPlan.committedTotalAmount;

  double _recommendedDisposableInput(BudgetStats stats, {required bool gross}) {
    final grossBase =
        (stats.budgetPlan.grossIncomeReference > 0
                ? stats.budgetPlan.grossIncomeReference
                : stats.averageIncome)
            .clamp(0, double.infinity)
            .toDouble();
    if (gross) return grossBase;
    return (grossBase - _totalCommittedAmount(stats))
        .clamp(0, double.infinity)
        .toDouble();
  }

  void _applyDisposablePreset(
    BudgetStats stats, {
    required bool grossMode,
    bool markDirty = true,
  }) {
    final value = _recommendedDisposableInput(stats, gross: grossMode);
    setState(() {
      _useGrossIncomeBase = grossMode;
      _draftDisposableIncome = value;
      _draftError = null;
      if (markDirty) _dirty = true;
    });
  }

  void _syncDraft(BudgetStats stats, {bool force = false}) {
    final token =
        '${stats.selectedYear}-${stats.selectedMonth}-${stats.budgetPlan.id}';
    if (!force && _draftToken == token) return;

    _draftToken = token;
    _useGrossIncomeBase = stats.budgetPlan.useGrossIncomeBase;
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
    final manualCapacityAmount = disposable;
    final manualCapacityPercent = 100.0;

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

          final committedAmount = (group.spentActual + group.pendingAmount)
              .clamp(0, double.infinity)
              .toDouble();
          final plannedAmountRaw = draft.inputMode == 'amount'
              ? draft.amount
              : disposable * draft.percent / 100;
          final plannedAmount = plannedAmountRaw > committedAmount
              ? plannedAmountRaw
              : committedAmount;
          final plannedPercent = disposable > 0
              ? (plannedAmount / disposable) * 100
              : (plannedAmount > 0 ? 100.0 : 0.0);
          final minAllowedPercent = disposable > 0
              ? (committedAmount / disposable) * 100
              : (committedAmount > 0 ? 100.0 : 0.0);

          return _RenderedGroup(
            group: group,
            draft: draft,
            plannedPercent: plannedPercent.clamp(0, double.infinity),
            plannedAmount: plannedAmount.clamp(0, double.infinity),
            minAllowedPercent: minAllowedPercent.clamp(0, double.infinity),
            minAllowedAmount: committedAmount,
            maxAllowedPercent: 100,
            maxAllowedAmount: disposable > committedAmount
                ? disposable
                : committedAmount,
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

    final rows = baseRows.map((row) {
      final dynamicMaxPercent =
          (manualCapacityPercent - (totalPercent - row.plannedPercent))
              .clamp(0, double.infinity)
              .toDouble();
      final dynamicMaxAmount =
          (manualCapacityAmount - (totalAmount - row.plannedAmount))
              .clamp(0, double.infinity)
              .toDouble();

      return _RenderedGroup(
        group: row.group,
        draft: row.draft,
        plannedPercent: row.plannedPercent,
        plannedAmount: row.plannedAmount,
        minAllowedPercent: row.minAllowedPercent,
        minAllowedAmount: row.minAllowedAmount,
        maxAllowedPercent: dynamicMaxPercent > row.minAllowedPercent
            ? dynamicMaxPercent
            : row.minAllowedPercent,
        maxAllowedAmount: dynamicMaxAmount > row.minAllowedAmount
            ? dynamicMaxAmount
            : row.minAllowedAmount,
      );
    }).toList();

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
    final manualCapacityAmount = disposable
        .clamp(0, double.infinity)
        .toDouble();
    final manualCapacityPercent = 100.0;
    final totalPercent = manualPercent;
    final totalAmount = manualAmount;
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

  String _saveErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['error'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
      if (error.response?.statusCode == 503) {
        return 'Serveur temporairement indisponible. Reessayez dans quelques secondes.';
      }
    }
    return 'Erreur de sauvegarde du plan.';
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
        useGrossIncomeBase: _useGrossIncomeBase,
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
    } catch (error) {
      setState(() {
        _draftError = _saveErrorMessage(error);
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

  Future<void> _createSavingsGoalFromBudget({
    required DateTime selectedMonth,
    required double disposableIncome,
  }) async {
    if (disposableIncome <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Definis d\'abord un revenu disponible positif pour ce mois.',
          ),
        ),
      );
      return;
    }

    final nameCtrl = TextEditingController(text: 'Epargne mensuelle');
    final percentCtrl = TextEditingController(text: '10');
    final monthsCtrl = TextEditingController(text: '12');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) {
          final pct = _parseNumber(percentCtrl.text).clamp(0, 100).toDouble();
          final months = int.tryParse(monthsCtrl.text.trim()) ?? 12;
          final validMonths = months.clamp(1, 120);
          final monthly = disposableIncome * pct / 100;
          final target = monthly * validMonths;
          final targetDate = DateTime(
            selectedMonth.year,
            selectedMonth.month + validMonths - 1,
            1,
          );

          return AlertDialog(
            title: const Text('Creer une epargne mensuelle'),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Le Budget gere les depenses. L\'epargne est geree via Objectifs.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    onChanged: (_) => setLocalState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Nom de l\'objectif',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: percentCtrl,
                    onChanged: (_) => setLocalState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Pourcentage du revenu disponible (%)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: monthsCtrl,
                    onChanged: (_) => setLocalState(() {}),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Horizon (mois)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(AppRadius.r10),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mensuel: ${AppFormats.currencyCompact.format(monthly)} (${pct.toStringAsFixed(1)}%)',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Objectif cible: ${AppFormats.currencyCompact.format(target)} sur $validMonths mois (jusqu\'a ${_monthNames[targetDate.month - 1]} ${targetDate.year})',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
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
                child: const Text('Creer'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;

    final goalName = nameCtrl.text.trim().isEmpty
        ? 'Epargne mensuelle'
        : nameCtrl.text.trim();
    final pct = _parseNumber(percentCtrl.text).clamp(0, 100).toDouble();
    final months = (int.tryParse(monthsCtrl.text.trim()) ?? 12).clamp(1, 120);
    final monthly = disposableIncome * pct / 100;

    if (monthly <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le pourcentage doit etre superieur a 0%.'),
        ),
      );
      return;
    }

    final targetDate = DateTime(
      selectedMonth.year,
      selectedMonth.month + months - 1,
      1,
    );
    final targetAmount = monthly * months;

    try {
      final api = ref.read(goalsApiProvider);
      await api.createGoal(
        name: goalName,
        goalType: 'savings',
        targetAmount: targetAmount,
        targetDate: targetDate,
        initialAmount: 0,
        monthlyContribution: monthly,
      );
      ref.invalidate(goalsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Objectif "$goalName" cree (${AppFormats.currencyCompact.format(monthly)}/mois).',
          ),
          action: SnackBarAction(
            label: 'Ouvrir Objectifs',
            onPressed: () => context.go('/goals'),
          ),
        ),
      );
    } on DioException catch (error) {
      final data = error.response?.data;
      final message = data is Map<String, dynamic> && data['error'] is String
          ? data['error'] as String
          : 'Erreur de creation de l\'objectif.';
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
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
        final grossReferenceIncome = _recommendedDisposableInput(
          stats,
          gross: true,
        );
        final manualCommittedAmount = _manualCommittedAmount(stats);
        final disposable =
            (_draftDisposableIncome ??
                    _recommendedDisposableInput(
                      stats,
                      gross: _useGrossIncomeBase,
                    ))
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
                    copiedFrom: stats.budgetPlan.copiedFrom,
                    grossReferenceIncome: grossReferenceIncome,
                    manualCommittedAmount: manualCommittedAmount,
                    useGrossIncomeBase: _useGrossIncomeBase,
                    onUseGrossIncomeBaseChanged: (value) =>
                        _applyDisposablePreset(stats, grossMode: value),
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
                  const SizedBox(height: 10),
                  _SavingsQuickCard(
                    disposableIncome: totals.manualCapacityAmount
                        .clamp(0, double.infinity)
                        .toDouble(),
                    onCreateGoal: () => _createSavingsGoalFromBudget(
                      selectedMonth: selectedMonth,
                      disposableIncome: totals.manualCapacityAmount
                          .clamp(0, double.infinity)
                          .toDouble(),
                    ),
                    onOpenGoals: () => context.go('/goals'),
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
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
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
    final monthLabel =
        '${_monthNames[selectedMonth.month - 1]} ${selectedMonth.year}';

    final actions = Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (dirty)
          const Text(
            'Modifications non sauvegardees',
            style: TextStyle(
              color: Color(0xFFB45309),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        OutlinedButton(onPressed: onReset, child: const Text('Recharger')),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 980;
        final monthNav = Row(
          children: [
            IconButton(
              onPressed: onPrevMonth,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                monthLabel,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 22 : 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            IconButton(
              onPressed: onNextMonth,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [monthNav, const SizedBox(height: 8), actions],
          );
        }

        return Row(
          children: [
            SizedBox(width: 420, child: monthNav),
            const Spacer(),
            actions,
          ],
        );
      },
    );
  }
}

class _PlannerHero extends StatelessWidget {
  final String inputVersion;
  final double disposable;
  final double grossReferenceIncome;
  final double manualCommittedAmount;
  final bool useGrossIncomeBase;
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
  final BudgetPlanCopySource? copiedFrom;
  final ValueChanged<bool> onUseGrossIncomeBaseChanged;
  final ValueChanged<String> onDisposableChanged;

  const _PlannerHero({
    required this.inputVersion,
    required this.disposable,
    required this.grossReferenceIncome,
    required this.manualCommittedAmount,
    required this.useGrossIncomeBase,
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
    required this.copiedFrom,
    required this.onUseGrossIncomeBaseChanged,
    required this.onDisposableChanged,
  });

  @override
  Widget build(BuildContext context) {
    final overLimit = totalPercent > 100.0001;
    final ratio = (totalPercent / 100).clamp(0.0, 1.0);
    final netRecommendedInput = (grossReferenceIncome - manualCommittedAmount)
        .clamp(0, double.infinity)
        .toDouble();
    final fullyNetAvailable =
        (grossReferenceIncome - manualCommittedAmount - autoAmount)
            .clamp(0, double.infinity)
            .toDouble();

    return AppPanel(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      radius: AppRadius.r20,
      borderColor: AppColors.borderSubtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(AppRadius.r10),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Text(
              'Etape 1: choisis la base du plan.\n'
              'Par defaut, on recommande ${AppFormats.currencyCompact.format(netRecommendedInput)} '
              '(revenu ${AppFormats.currencyCompact.format(grossReferenceIncome)} - factures manuelles ${AppFormats.currencyCompact.format(manualCommittedAmount)} - prelevements auto ${AppFormats.currencyCompact.format(autoAmount)}).',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Base de plan (modifiable)',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(
                width: 220,
                child: _SyncedNumericField(
                  key: ValueKey('disposable-$inputVersion'),
                  valueText: _editableInputValue(disposable, maxDecimals: 0),
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
              Text(
                useGrossIncomeBase
                    ? 'Mode brut: on ne retire pas les factures automatiquement.'
                    : 'Mode net recommande: base deja nettoyee avant repartition.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              InkWell(
                onTap: () => onUseGrossIncomeBaseChanged(!useGrossIncomeBase),
                borderRadius: BorderRadius.circular(AppRadius.r8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: useGrossIncomeBase,
                        onChanged: (v) =>
                            onUseGrossIncomeBaseChanged(v ?? false),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Voir vraie somme brute (sans factures du mois)',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (autoAmount > 0)
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
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${totalPercent.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: overLimit ? AppColors.danger : AppColors.primary,
                ),
              ),
              const Text(
                'de la base deja repartie',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                'Manual: ${manualPercent.toStringAsFixed(1)}% / ${manualCapacityPercent.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '${AppFormats.currencyCompact.format(totalAmount)} deja repartis',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.danger,
                ),
              ),
              Text(
                '${remainingAmount >= 0 ? AppFormats.currencyCompact.format(remainingAmount) : '0'} encore libres',
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
            'Etape 2: capacite de repartition ${AppFormats.currencyCompact.format(manualCapacityAmount)} '
            '- deja reparti ${AppFormats.currencyCompact.format(manualAmount)}'
            '${remainingPercent < 0 ? ' - deficit global' : ''}',
            style: TextStyle(
              fontSize: 12,
              color: remainingPercent < 0
                  ? AppColors.danger
                  : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Etape 3: disponible reel apres toutes les factures du mois (payees + a payer + auto): '
            '${AppFormats.currencyCompact.format(fullyNetAvailable)}',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
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

class _SavingsQuickCard extends StatelessWidget {
  final double disposableIncome;
  final VoidCallback onCreateGoal;
  final VoidCallback onOpenGoals;

  const _SavingsQuickCard({
    required this.disposableIncome,
    required this.onCreateGoal,
    required this.onOpenGoals,
  });

  @override
  Widget build(BuildContext context) {
    final canCreate = disposableIncome > 0;

    return AppPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      radius: AppRadius.r16,
      borderColor: const Color(0xFFDCE7D3),
      backgroundColor: const Color(0xFFF7FBF4),
      child: Row(
        children: [
          const Icon(
            Icons.savings_outlined,
            color: AppColors.primary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Epargne mensuelle',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  canCreate
                      ? 'Definis un % du revenu disponible pour creer un objectif d\'epargne.'
                      : 'Definis le revenu disponible du mois pour activer l\'epargne mensuelle.',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: onOpenGoals,
            child: const Text('Objectifs'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: canCreate ? onCreateGoal : null,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Creer epargne'),
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
            'Ces montants viennent des prelevements automatiques deja prevus.'
            ' Vous n\'avez rien a ressaisir dans les cartes manuelles.',
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
    final hasEnvelope = row.plannedAmount > 0.0001;
    final paidAmount = row.group.spentActual;
    final pendingAmount = row.group.pendingAmount;
    final committedAmount = paidAmount + pendingAmount;
    final usagePct = hasEnvelope
        ? (committedAmount / row.plannedAmount) * 100
        : 0.0;
    final overUsage = hasEnvelope && committedAmount > row.plannedAmount;
    final overflowAmount = hasEnvelope
        ? (committedAmount > row.plannedAmount
              ? committedAmount - row.plannedAmount
              : 0.0)
        : committedAmount;
    final lockedByCommitted =
        row.minAllowedAmount > 0 &&
        row.plannedAmount <= row.minAllowedAmount + 0.0001;
    final paidRatio = hasEnvelope
        ? (paidAmount / row.plannedAmount).clamp(0.0, 1.0)
        : 0.0;
    final pendingRatio = hasEnvelope
        ? (pendingAmount / row.plannedAmount).clamp(0.0, 1.0 - paidRatio)
        : 0.0;
    final freeRatio = hasEnvelope
        ? (1.0 - paidRatio - pendingRatio).clamp(0.0, 1.0)
        : 0.0;
    final spentDelta = row.plannedAmount - committedAmount;
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Payees: ${AppFormats.currencyCompact.format(paidAmount)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  if (pendingAmount > 0)
                    Text(
                      'A payer: ${AppFormats.currencyCompact.format(pendingAmount)}',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                ],
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
                child: _SyncedNumericField(
                  key: ValueKey(
                    '$inputVersion-${row.group.groupId}-${row.draft.inputMode}',
                  ),
                  valueText: row.draft.inputMode == 'amount'
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
                !hasEnvelope && committedAmount > 0
                    ? 'Montant deja engage ce mois: ${AppFormats.currencyCompact.format(committedAmount)}'
                    : !hasEnvelope
                    ? 'Budget non defini'
                    : 'Deja engage (paye + a payer): ${usagePct.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: overUsage && hasEnvelope
                      ? AppColors.danger
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                !hasEnvelope
                    ? 'Budget planifie: 0'
                    : spentDelta >= 0
                    ? 'Reste libre: ${AppFormats.currencyCompact.format(spentDelta)}'
                    : 'Depassement deja engage: ${AppFormats.currencyCompact.format(-spentDelta)}',
                style: TextStyle(
                  color: hasEnvelope && spentDelta < 0
                      ? AppColors.danger
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (hasEnvelope) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.r8),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    if (paidRatio > 0)
                      Expanded(
                        flex: ((paidRatio * 1000).round())
                            .clamp(1, 1000)
                            .toInt(),
                        child: const ColoredBox(color: AppColors.danger),
                      ),
                    if (pendingRatio > 0)
                      Expanded(
                        flex: ((pendingRatio * 1000).round())
                            .clamp(1, 1000)
                            .toInt(),
                        child: const ColoredBox(color: AppColors.warning),
                      ),
                    if (freeRatio > 0)
                      Expanded(
                        flex: ((freeRatio * 1000).round())
                            .clamp(1, 1000)
                            .toInt(),
                        child: const ColoredBox(color: AppColors.primary),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                Text(
                  'Rouge: deja paye ${AppFormats.currencyCompact.format(paidAmount)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
                Text(
                  'Jaune: a payer ${AppFormats.currencyCompact.format(pendingAmount)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
                Text(
                  'Vert: libre ${AppFormats.currencyCompact.format(spentDelta > 0 ? spentDelta : 0)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
          if (lockedByCommitted) ...[
            const SizedBox(height: 6),
            Text(
              'On a automatiquement mis ce plan au minimum de ${AppFormats.currencyCompact.format(row.minAllowedAmount)} pour ne pas descendre sous le deja engage.',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (overflowAmount > 0 && hasEnvelope) ...[
            const SizedBox(height: 4),
            Text(
              'Attention: ${AppFormats.currencyCompact.format(overflowAmount)} deja engages au-dessus du plan.',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.danger,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SyncedNumericField extends StatefulWidget {
  final String valueText;
  final ValueChanged<String> onChanged;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final InputDecoration? decoration;

  const _SyncedNumericField({
    super.key,
    required this.valueText,
    required this.onChanged,
    this.keyboardType = TextInputType.number,
    this.inputFormatters,
    this.decoration,
  });

  @override
  State<_SyncedNumericField> createState() => _SyncedNumericFieldState();
}

class _SyncedNumericFieldState extends State<_SyncedNumericField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.valueText);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _SyncedNumericField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.valueText == _controller.text) return;
    _controller.value = TextEditingValue(
      text: widget.valueText,
      selection: TextSelection.collapsed(offset: widget.valueText.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      onChanged: widget.onChanged,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      decoration: widget.decoration,
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
