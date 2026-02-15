import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/features/budget/providers/budget_provider.dart';
import 'package:solver/features/budget/providers/goals_provider.dart';
import 'package:solver/shared/widgets/app_panel.dart';

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

bool _isDebtType(String value) => value.toLowerCase() == 'debt';

String _typeLabel(String value) =>
    _isDebtType(value) ? 'Remboursement' : 'Objectif';

int _monthsRemaining(DateTime from, DateTime target) {
  final monthDelta =
      (target.year - from.year) * 12 + (target.month - from.month) + 1;
  return monthDelta < 0 ? 0 : monthDelta;
}

DateTime? _projectedDate(double remaining, double monthlyAmount) {
  if (remaining <= 0) return DateTime.now();
  if (monthlyAmount <= 0) return null;
  final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
  final monthsToGoal = (remaining / monthlyAmount).ceil();
  return DateTime(monthStart.year, monthStart.month + monthsToGoal - 1, 1);
}

int _monthIndex(DateTime d) => d.year * 12 + d.month;

class _DebtRiskAssessment {
  final String label;
  final Color color;
  final int? projectedDelayMonths;
  final double? marginAfterPayment;

  const _DebtRiskAssessment({
    required this.label,
    required this.color,
    required this.projectedDelayMonths,
    required this.marginAfterPayment,
  });
}

_DebtRiskAssessment _assessDebtRisk(SavingGoal goal, double? monthlyMargin) {
  int score = 0;

  int? delayMonths;
  if (goal.remainingAmount <= 0) {
    delayMonths = 0;
  } else if (goal.projectedDate != null) {
    final delay =
        _monthIndex(goal.projectedDate!) - _monthIndex(goal.targetDate);
    delayMonths = delay > 0 ? delay : 0;
  }

  if (goal.remainingAmount > 0) {
    if (goal.projectedDate == null) {
      score += 70;
    } else if ((delayMonths ?? 0) >= 6) {
      score += 70;
    } else if ((delayMonths ?? 0) >= 3) {
      score += 50;
    } else if ((delayMonths ?? 0) >= 1) {
      score += 30;
    }

    if (goal.recommendedMonthly > 0 &&
        goal.monthlyContribution + 0.01 < goal.recommendedMonthly) {
      score += 20;
    }
  }

  double? marginAfterPayment;
  if (monthlyMargin != null) {
    marginAfterPayment = monthlyMargin - goal.monthlyContribution;
    if (marginAfterPayment < 0) {
      score += 35;
    } else if (marginAfterPayment < 100) {
      score += 20;
    } else if (marginAfterPayment < 250) {
      score += 10;
    }
  }

  if (score >= 70) {
    return _DebtRiskAssessment(
      label: 'Risque eleve',
      color: AppColors.danger,
      projectedDelayMonths: delayMonths,
      marginAfterPayment: marginAfterPayment,
    );
  }
  if (score >= 40) {
    return _DebtRiskAssessment(
      label: 'Risque moyen',
      color: const Color(0xFFB45309),
      projectedDelayMonths: delayMonths,
      marginAfterPayment: marginAfterPayment,
    );
  }
  return _DebtRiskAssessment(
    label: 'Risque faible',
    color: AppColors.primary,
    projectedDelayMonths: delayMonths,
    marginAfterPayment: marginAfterPayment,
  );
}

class GoalsView extends ConsumerStatefulWidget {
  const GoalsView({super.key});

  @override
  ConsumerState<GoalsView> createState() => _GoalsViewState();
}

class _GoalsViewState extends ConsumerState<GoalsView> {
  String _activeType = 'savings';

  Future<void> _showGoalEditor({SavingGoal? goal, String? forcedType}) async {
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
    var goalType = goal?.goalType ?? forcedType ?? _activeType;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) {
          final targetAmount = _parseNumber(targetCtrl.text);
          final initialAmount = _parseNumber(initialCtrl.text);
          final monthlyAmount = _parseNumber(monthlyCtrl.text);
          final remaining = (targetAmount - initialAmount).clamp(
            0,
            double.infinity,
          );
          final monthsRemaining = _monthsRemaining(DateTime.now(), targetDate);
          final recommendedMonthly = remaining <= 0
              ? 0.0
              : monthsRemaining > 0
              ? remaining / monthsRemaining
              : remaining;
          final projected = _projectedDate(remaining.toDouble(), monthlyAmount);

          final isDebt = _isDebtType(goalType);
          final dialogTitle = goal == null
              ? (isDebt ? 'Nouveau remboursement' : 'Nouvel objectif')
              : (isDebt ? 'Modifier remboursement' : 'Modifier objectif');
          final targetLabel = isDebt
              ? 'Montant total de la dette (${AppFormats.currencyCode})'
              : 'Montant cible (${AppFormats.currencyCode})';
          final initialLabel = isDebt
              ? 'Deja rembourse (${AppFormats.currencyCode})'
              : 'Montant initial (${AppFormats.currencyCode})';
          final monthlyLabel = isDebt
              ? 'Remboursement mensuel (${AppFormats.currencyCode})'
              : 'Contribution mensuelle (${AppFormats.currencyCode})';

          return AlertDialog(
            title: Text(dialogTitle),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Objectif'),
                            selected: !_isDebtType(goalType),
                            selectedColor: AppColors.primary.withAlpha(28),
                            labelStyle: TextStyle(
                              color: !_isDebtType(goalType)
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w800,
                            ),
                            onSelected: (_) =>
                                setLocalState(() => goalType = 'savings'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Remboursement'),
                            selected: _isDebtType(goalType),
                            selectedColor: AppColors.danger.withAlpha(24),
                            labelStyle: TextStyle(
                              color: _isDebtType(goalType)
                                  ? AppColors.danger
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w800,
                            ),
                            onSelected: (_) =>
                                setLocalState(() => goalType = 'debt'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      onChanged: (_) => setLocalState(() {}),
                      decoration: const InputDecoration(labelText: 'Nom'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: targetCtrl,
                      onChanged: (_) => setLocalState(() {}),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
                      ],
                      decoration: InputDecoration(labelText: targetLabel),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: initialCtrl,
                      onChanged: (_) => setLocalState(() {}),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
                      ],
                      decoration: InputDecoration(labelText: initialLabel),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: monthlyCtrl,
                      onChanged: (_) => setLocalState(() {}),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
                      ],
                      decoration: InputDecoration(labelText: monthlyLabel),
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
                    const SizedBox(height: 8),
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
                            'Recommande pour la date cible: ${AppFormats.currencyCompact.format(recommendedMonthly)} / mois',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            projected == null
                                ? 'Avec ton montant mensuel: projection indisponible (0/mois)'
                                : 'Avec ton montant mensuel: fin estimee ${projected.month.toString().padLeft(2, '0')}.${projected.year}',
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
          );
        },
      ),
    );

    if (confirmed != true) return;

    try {
      final api = ref.read(goalsApiProvider);
      if (goal == null) {
        await api.createGoal(
          name: nameCtrl.text.trim(),
          goalType: goalType,
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
          goalType: goalType,
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
        ).showSnackBar(const SnackBar(content: Text('Enregistre')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Erreur de sauvegarde')));
      }
    }
  }

  Future<void> _showGoalEntryEditor(SavingGoal goal) async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    var isDeposit = true;
    final isDebt = _isDebtType(goal.goalType);

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
                        label: Text(isDebt ? 'Paiement' : 'Depot'),
                        selected: isDeposit,
                        onSelected: (_) =>
                            setLocalState(() => isDeposit = true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Correction -'),
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
                              child: Text('Aucun mouvement pour cet element.'),
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
    final goalsAsync = ref.watch(goalsProvider);
    final selectedBudgetMonth = ref.watch(selectedBudgetMonthProvider);
    final budgetAsync = ref.watch(
      budgetStatsProvider(
        BudgetMonthKey(
          year: selectedBudgetMonth.year,
          month: selectedBudgetMonth.month,
        ),
      ),
    );
    final monthlyMarginAvailable = budgetAsync.maybeWhen(
      data: (stats) =>
          stats.budgetPlan.forecastDisposableIncome -
          stats.budgetPlan.totalAllocatedAmount,
      orElse: () => null,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1380),
          child: AppPanel(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            radius: AppRadius.r20,
            borderColor: AppColors.borderSubtle,
            child: goalsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(
                'Erreur objectifs: $e',
                style: const TextStyle(color: AppColors.danger),
              ),
              data: (goals) {
                final filtered = goals
                    .where((g) => g.goalType.toLowerCase() == _activeType)
                    .toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'OBJECTIFS & REMBOURSEMENTS',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDisabled,
                                fontSize: 11,
                                letterSpacing: 1.1,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Planifie tes objectifs et tes credits long terme',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(AppRadius.r12),
                          ),
                          child: Row(
                            children: [
                              _TypeButton(
                                label: 'Objectifs',
                                isActive: !_isDebtType(_activeType),
                                activeColor: AppColors.primary,
                                onTap: () =>
                                    setState(() => _activeType = 'savings'),
                              ),
                              _TypeButton(
                                label: 'Remboursements',
                                isActive: _isDebtType(_activeType),
                                activeColor: AppColors.danger,
                                onTap: () =>
                                    setState(() => _activeType = 'debt'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () =>
                              _showGoalEditor(forcedType: _activeType),
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(
                            _isDebtType(_activeType)
                                ? 'Nouveau remboursement'
                                : 'Nouvel objectif',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_isDebtType(_activeType))
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(AppRadius.r10),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Text(
                          monthlyMarginAvailable == null
                              ? 'Marge mensuelle restante: indisponible (ouvre Budget pour initialiser le mois).'
                              : 'Marge mensuelle restante (apres allocations): ${AppFormats.currencyCompact.format(monthlyMarginAvailable)}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          _isDebtType(_activeType)
                              ? 'Aucun remboursement pour le moment.'
                              : 'Aucun objectif pour le moment.',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          for (int i = 0; i < filtered.length; i++)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: i == filtered.length - 1 ? 0 : 10,
                              ),
                              child: _GoalCard(
                                goal: filtered[i],
                                monthlyMarginAvailable: monthlyMarginAvailable,
                                onEdit: () =>
                                    _showGoalEditor(goal: filtered[i]),
                                onMove: () => _showGoalEntryEditor(filtered[i]),
                                onHistory: () => _showGoalHistory(filtered[i]),
                                onArchive: () async {
                                  await ref
                                      .read(goalsApiProvider)
                                      .archiveGoal(
                                        id: filtered[i].id,
                                        isArchived: !filtered[i].isArchived,
                                      );
                                  ref.invalidate(goalsProvider);
                                },
                              ),
                            ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withAlpha(22) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.r10),
          border: Border.all(
            color: isActive ? activeColor.withAlpha(80) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? activeColor : AppColors.textSecondary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final SavingGoal goal;
  final double? monthlyMarginAvailable;
  final VoidCallback onEdit;
  final VoidCallback onMove;
  final VoidCallback onHistory;
  final VoidCallback onArchive;

  const _GoalCard({
    required this.goal,
    required this.monthlyMarginAvailable,
    required this.onEdit,
    required this.onMove,
    required this.onHistory,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final isDebt = _isDebtType(goal.goalType);
    final statusColor = _statusColor(goal.status);
    final progress = (goal.progressPercent / 100).clamp(0.0, 1.0);
    final projected = goal.projectedDate;
    final typeColor = isDebt ? AppColors.danger : AppColors.primary;
    final risk = isDebt ? _assessDebtRisk(goal, monthlyMarginAvailable) : null;
    final delayText = risk == null
        ? null
        : risk.projectedDelayMonths == null
        ? 'Retard previsionnel: indetermine'
        : 'Retard previsionnel: ${risk.projectedDelayMonths} mois';
    final marginText = risk == null
        ? null
        : risk.marginAfterPayment == null
        ? 'Marge restante apres mensualite: indisponible'
        : risk.marginAfterPayment! >= 0
        ? 'Marge restante apres mensualite: ${AppFormats.currencyCompact.format(risk.marginAfterPayment)}'
        : 'Marge restante apres mensualite: -${AppFormats.currencyCompact.format(risk.marginAfterPayment!.abs())}';

    return AppPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: AppRadius.r16,
      borderColor: typeColor.withAlpha(90),
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
                  color: typeColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(AppRadius.r8),
                ),
                child: Text(
                  _typeLabel(goal.goalType),
                  style: TextStyle(
                    color: typeColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 6),
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
                isDebt
                    ? 'Reste a rembourser ${AppFormats.currencyCompact.format(goal.remainingAmount)}'
                    : 'Reste ${AppFormats.currencyCompact.format(goal.remainingAmount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: isDebt ? AppColors.danger : AppColors.textPrimary,
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
              valueColor: AlwaysStoppedAnimation<Color>(typeColor),
            ),
          ),
          if (risk != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: risk.color.withAlpha(18),
                borderRadius: BorderRadius.circular(AppRadius.r10),
                border: Border.all(color: risk.color.withAlpha(80)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    risk.label,
                    style: TextStyle(
                      color: risk.color,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    delayText!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    marginText!,
                    style: TextStyle(
                      color: risk.marginAfterPayment == null
                          ? AppColors.textSecondary
                          : (risk.marginAfterPayment! >= 0
                                ? AppColors.primary
                                : AppColors.danger),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              Text(
                '${isDebt ? 'Mensuel de remboursement' : 'Mensuel actuel'}: ${AppFormats.currencyCompact.format(goal.monthlyContribution)}',
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
                child: Text(isDebt ? 'Paiement' : 'Depot/Retrait'),
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
