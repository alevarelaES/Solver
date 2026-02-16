import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/features/budget/providers/budget_provider.dart';
import 'package:solver/features/budget/providers/goals_provider.dart';
import 'package:solver/shared/widgets/app_panel.dart';

double _parseNumber(String raw) =>
    double.tryParse(raw.replaceAll(' ', '').replaceAll(',', '.')) ?? 0.0;

String _editableInputValue(double value, {int maxDecimals = 0}) {
  if (value.abs() < 0.000001) return '';
  final text = value.toStringAsFixed(maxDecimals);
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}

bool _isDebtType(String value) => value.toLowerCase() == 'debt';

String _typeLabel(String value) =>
    _isDebtType(value) ? 'Remboursement' : 'Objectif';

bool _isAchievedStatus(String status) => status.toLowerCase() == 'achieved';

String _formatDateShort(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d.$m.${date.year}';
}

int _daysUntil(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  return target.difference(today).inDays;
}

enum _GoalAlertLevel { normal, attention, critical, overdue, achieved }

class _GoalAlertAssessment {
  final _GoalAlertLevel level;
  final String label;
  final Color color;
  final IconData icon;

  const _GoalAlertAssessment({
    required this.level,
    required this.label,
    required this.color,
    required this.icon,
  });

  bool get isPriority =>
      level == _GoalAlertLevel.critical || level == _GoalAlertLevel.overdue;

  bool get isAttention => level == _GoalAlertLevel.attention;
}

int _projectedDelayMonths(SavingGoal goal) {
  if (goal.projectedDate == null) {
    return goal.remainingAmount > 0 ? 999 : 0;
  }
  final delay = _monthIndex(goal.projectedDate!) - _monthIndex(goal.targetDate);
  return delay > 0 ? delay : 0;
}

_GoalAlertAssessment _assessGoalAlert(SavingGoal goal) {
  if (_isAchievedStatus(goal.status) || goal.remainingAmount <= 0.01) {
    return const _GoalAlertAssessment(
      level: _GoalAlertLevel.achieved,
      label: 'Atteint',
      color: AppColors.primary,
      icon: Icons.check_circle_rounded,
    );
  }

  final days = _daysUntil(goal.targetDate);
  if (days < 0) {
    return const _GoalAlertAssessment(
      level: _GoalAlertLevel.overdue,
      label: 'Echeance depassee',
      color: AppColors.danger,
      icon: Icons.error_rounded,
    );
  }

  final requiredMonthly = goal.recommendedMonthly <= 0
      ? 0.0
      : goal.recommendedMonthly;
  final hasPlan = goal.monthlyContribution > 0.01;
  final coverage = requiredMonthly <= 0
      ? 1.0
      : goal.monthlyContribution / requiredMonthly;
  final delayMonths = _projectedDelayMonths(goal);

  if (days <= 15) {
    if (!hasPlan || coverage < 0.80 || delayMonths >= 1) {
      return const _GoalAlertAssessment(
        level: _GoalAlertLevel.critical,
        label: 'Urgence: echeance proche',
        color: AppColors.danger,
        icon: Icons.priority_high_rounded,
      );
    }
    return const _GoalAlertAssessment(
      level: _GoalAlertLevel.attention,
      label: 'Attention: bientot',
      color: AppColors.warning,
      icon: Icons.warning_amber_rounded,
    );
  }

  if (days <= 30) {
    if (!hasPlan || coverage < 0.55 || delayMonths >= 2) {
      return const _GoalAlertAssessment(
        level: _GoalAlertLevel.critical,
        label: 'Urgence: ajustement fort',
        color: AppColors.danger,
        icon: Icons.priority_high_rounded,
      );
    }
    if (coverage < 0.95 || delayMonths >= 1) {
      return const _GoalAlertAssessment(
        level: _GoalAlertLevel.attention,
        label: 'Attention: a ajuster',
        color: AppColors.warning,
        icon: Icons.warning_amber_rounded,
      );
    }
  }

  if (days <= 60) {
    if (!hasPlan || coverage < 0.75 || delayMonths >= 2) {
      return const _GoalAlertAssessment(
        level: _GoalAlertLevel.attention,
        label: 'Attention: approche',
        color: AppColors.warning,
        icon: Icons.warning_amber_rounded,
      );
    }
  }

  if (days <= 90 && coverage < 0.65 && delayMonths >= 1) {
    return const _GoalAlertAssessment(
      level: _GoalAlertLevel.attention,
      label: 'Attention: rythme faible',
      color: AppColors.warning,
      icon: Icons.warning_amber_rounded,
    );
  }

  if (!hasPlan && goal.remainingAmount > 0) {
    return const _GoalAlertAssessment(
      level: _GoalAlertLevel.normal,
      label: 'A planifier',
      color: AppColors.textSecondary,
      icon: Icons.schedule_rounded,
    );
  }

  if (coverage < 0.95 || delayMonths >= 1) {
    return const _GoalAlertAssessment(
      level: _GoalAlertLevel.normal,
      label: 'A ajuster',
      color: AppColors.textSecondary,
      icon: Icons.tune_rounded,
    );
  }

  return const _GoalAlertAssessment(
    level: _GoalAlertLevel.normal,
    label: 'Sur trajectoire',
    color: Color(0xFF15803D),
    icon: Icons.track_changes_rounded,
  );
}

String _deadlineLabel(SavingGoal goal) {
  final days = _daysUntil(goal.targetDate);
  if (_isAchievedStatus(goal.status)) {
    return 'Atteint - cible ${_formatDateShort(goal.targetDate)}';
  }
  if (days < 0) return 'Retard de ${days.abs()} jours';
  if (days == 0) return 'Echeance aujourd\'hui';
  if (days == 1) return 'Echeance demain';
  return 'Echeance dans $days jours';
}

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
      text: goal == null ? '' : _editableInputValue(goal.targetAmount),
    );
    final initialCtrl = TextEditingController(
      text: goal == null ? '' : _editableInputValue(goal.initialAmount),
    );
    final monthlyCtrl = TextEditingController(
      text: goal == null ? '' : _editableInputValue(goal.monthlyContribution),
    );
    final priorityCtrl = TextEditingController(
      text: goal == null ? '' : goal.priority.toString(),
    );
    DateTime targetDate =
        goal?.targetDate ?? DateTime.now().add(const Duration(days: 365));
    var goalType = goal?.goalType ?? forcedType ?? _activeType;
    var autoContributionEnabled = goal?.autoContributionEnabled ?? false;
    DateTime? autoContributionStartDate = goal?.autoContributionStartDate;

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
                    const SizedBox(height: 4),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: autoContributionEnabled,
                      onChanged: (value) => setLocalState(() {
                        autoContributionEnabled = value;
                        if (value && autoContributionStartDate == null) {
                          autoContributionStartDate = DateTime.now();
                        }
                      }),
                      title: Text(
                        isDebt
                            ? 'Paiement automatique mensuel'
                            : 'Depot automatique mensuel',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: const Text(
                        'Si active, une entree auto est ajoutee chaque mois selon le montant mensuel.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (autoContributionEnabled)
                      Row(
                        children: [
                          const Text(
                            'Date du premier depot auto',
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
                                initialDate:
                                    autoContributionStartDate ?? DateTime.now(),
                                firstDate: DateTime(2020, 1, 1),
                                lastDate: DateTime(2100, 12, 31),
                              );
                              if (picked != null) {
                                setLocalState(
                                  () => autoContributionStartDate = picked,
                                );
                              }
                            },
                            child: Text(
                              autoContributionStartDate == null
                                  ? 'Choisir une date'
                                  : '${autoContributionStartDate!.day.toString().padLeft(2, '0')}.${autoContributionStartDate!.month.toString().padLeft(2, '0')}.${autoContributionStartDate!.year}',
                            ),
                          ),
                        ],
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
          autoContributionEnabled: autoContributionEnabled,
          autoContributionStartDate: autoContributionEnabled
              ? autoContributionStartDate
              : null,
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
          autoContributionEnabled: autoContributionEnabled,
          autoContributionStartDate: autoContributionEnabled
              ? autoContributionStartDate
              : null,
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
    final availableNow = goal.currentAmount;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) {
          final entered = _parseNumber(amountCtrl.text);
          final projected = isDeposit
              ? availableNow + entered
              : availableNow - entered;
          final invalidWithdraw = !isDeposit && projected < 0;

          return AlertDialog(
            title: Text('Mouvement - ${goal.name}'),
            content: SizedBox(
              width: 440,
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
                    onChanged: (_) => setLocalState(() {}),
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
                          'Disponible actuel: ${AppFormats.currencyCompact.format(availableNow)}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isDeposit
                              ? 'Apres depot: ${AppFormats.currencyCompact.format(projected)}'
                              : 'Apres retrait: ${AppFormats.currencyCompact.format(projected)}',
                          style: TextStyle(
                            color: invalidWithdraw
                                ? AppColors.danger
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
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
          );
        },
      ),
    );

    if (confirmed != true) return;

    try {
      final amount = _parseNumber(amountCtrl.text);
      if (amount <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Montant invalide')));
        }
        return;
      }
      if (!isDeposit && amount > availableNow) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Retrait superieur au disponible')),
          );
        }
        return;
      }
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
    } catch (e) {
      String message = 'Erreur de mouvement';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map) {
          if (data['error'] is String &&
              (data['error'] as String).trim().isNotEmpty) {
            message = data['error'] as String;
          } else if (data['detail'] is String &&
              (data['detail'] as String).trim().isNotEmpty) {
            message = data['detail'] as String;
          } else if (data['title'] is String &&
              (data['title'] as String).trim().isNotEmpty) {
            message = data['title'] as String;
          }
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
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
                final filtered =
                    goals
                        .where((g) => g.goalType.toLowerCase() == _activeType)
                        .toList()
                      ..sort((a, b) {
                        final aAchieved = _isAchievedStatus(a.status);
                        final bAchieved = _isAchievedStatus(b.status);
                        if (aAchieved != bAchieved) {
                          return aAchieved ? 1 : -1;
                        }
                        final dateCmp = a.targetDate.compareTo(b.targetDate);
                        if (dateCmp != 0) return dateCmp;
                        return a.priority.compareTo(b.priority);
                      });
                final pending = filtered
                    .where((g) => !_isAchievedStatus(g.status))
                    .toList();
                final achieved = filtered
                    .where((g) => _isAchievedStatus(g.status))
                    .toList();
                final goalAlerts = <String, _GoalAlertAssessment>{
                  for (final goal in filtered) goal.id: _assessGoalAlert(goal),
                };
                final urgent = pending
                    .where(
                      (g) =>
                          (goalAlerts[g.id] ?? _assessGoalAlert(g)).isPriority,
                    )
                    .toList();
                final attention = pending
                    .where(
                      (g) =>
                          (goalAlerts[g.id] ?? _assessGoalAlert(g)).isAttention,
                    )
                    .toList();
                final regular = pending.where((g) {
                  final alert = goalAlerts[g.id] ?? _assessGoalAlert(g);
                  return !alert.isPriority && !alert.isAttention;
                }).toList();
                final totalTarget = filtered.fold<double>(
                  0,
                  (sum, g) => sum + g.targetAmount,
                );
                final totalCurrent = filtered.fold<double>(
                  0,
                  (sum, g) => sum + g.currentAmount,
                );
                final totalMonthly = filtered.fold<double>(
                  0,
                  (sum, g) => sum + g.monthlyContribution,
                );
                final averageProgress = filtered.isEmpty
                    ? 0.0
                    : filtered.fold<double>(
                            0,
                            (sum, g) => sum + g.progressPercent,
                          ) /
                          filtered.length;
                final overdueCount = pending
                    .where(
                      (g) =>
                          (goalAlerts[g.id] ?? _assessGoalAlert(g)).level ==
                          _GoalAlertLevel.overdue,
                    )
                    .length;
                final typeColor = _isDebtType(_activeType)
                    ? AppColors.danger
                    : AppColors.primary;

                Widget buildSection({
                  required String title,
                  required String subtitle,
                  required IconData icon,
                  required Color accent,
                  required List<SavingGoal> sectionGoals,
                }) {
                  return _GoalsSection(
                    title: title,
                    subtitle: subtitle,
                    icon: icon,
                    accent: accent,
                    child: Column(
                      children: [
                        for (int i = 0; i < sectionGoals.length; i++)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: i == sectionGoals.length - 1 ? 0 : 10,
                            ),
                            child: _GoalCard(
                              goal: sectionGoals[i],
                              alert:
                                  goalAlerts[sectionGoals[i].id] ??
                                  _assessGoalAlert(sectionGoals[i]),
                              monthlyMarginAvailable: monthlyMarginAvailable,
                              onEdit: () =>
                                  _showGoalEditor(goal: sectionGoals[i]),
                              onMove: () =>
                                  _showGoalEntryEditor(sectionGoals[i]),
                              onHistory: () =>
                                  _showGoalHistory(sectionGoals[i]),
                              onArchive: () async {
                                await ref
                                    .read(goalsApiProvider)
                                    .archiveGoal(
                                      id: sectionGoals[i].id,
                                      isArchived: !sectionGoals[i].isArchived,
                                    );
                                ref.invalidate(goalsProvider);
                              },
                            ),
                          ),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 980;
                        final titleBlock = const Column(
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
                              'Trie automatiquement par echeance la plus proche',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        );
                        final controls = Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.r12,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
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
                        );

                        if (compact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              titleBlock,
                              const SizedBox(height: 10),
                              controls,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: titleBlock),
                            const SizedBox(width: 14),
                            Flexible(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: controls,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            typeColor.withAlpha(24),
                            const Color(0xFFF8FAFC),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.r16),
                        border: Border.all(color: typeColor.withAlpha(70)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _isDebtType(_activeType)
                                      ? 'Pilotage des remboursements'
                                      : 'Tableau de pilotage des objectifs',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: typeColor.withAlpha(26),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.r8,
                                  ),
                                ),
                                child: Text(
                                  '${filtered.length} carte${filtered.length > 1 ? 's' : ''}',
                                  style: TextStyle(
                                    color: typeColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _OverviewMetric(
                                icon: Icons.flag_rounded,
                                label: 'Cible totale',
                                value: AppFormats.currencyCompact.format(
                                  totalTarget,
                                ),
                                accent: typeColor,
                              ),
                              _OverviewMetric(
                                icon: Icons.account_balance_wallet_rounded,
                                label: 'Capital actuel',
                                value: AppFormats.currencyCompact.format(
                                  totalCurrent,
                                ),
                                accent: const Color(0xFF15803D),
                              ),
                              _OverviewMetric(
                                icon: Icons.trending_up_rounded,
                                label: 'Progression moyenne',
                                value: '${averageProgress.toStringAsFixed(1)}%',
                                accent: AppColors.info,
                              ),
                              _OverviewMetric(
                                icon: Icons.payments_rounded,
                                label: 'Mensuel cumule',
                                value: AppFormats.currencyCompact.format(
                                  totalMonthly,
                                ),
                                accent: AppColors.warning,
                              ),
                              _OverviewMetric(
                                icon: Icons.notifications_active_rounded,
                                label: 'Alertes',
                                value:
                                    '$overdueCount en retard / ${urgent.length} urgents / ${attention.length} attention',
                                accent: urgent.isNotEmpty || overdueCount > 0
                                    ? AppColors.danger
                                    : AppColors.warning,
                              ),
                              _OverviewMetric(
                                icon: Icons.task_alt_rounded,
                                label: 'Atteints',
                                value: '${achieved.length}',
                                accent: AppColors.primary,
                              ),
                            ],
                          ),
                          if (_isDebtType(_activeType)) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(170),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.r10,
                                ),
                                border: Border.all(
                                  color: AppColors.borderSubtle,
                                ),
                              ),
                              child: Text(
                                monthlyMarginAvailable == null
                                    ? 'Marge mensuelle restante: indisponible (ouvre Budget pour initialiser le mois).'
                                    : 'Marge mensuelle restante apres allocations: ${AppFormats.currencyCompact.format(monthlyMarginAvailable)}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (filtered.isEmpty)
                      AppPanel(
                        radius: AppRadius.r16,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 16,
                        ),
                        borderColor: AppColors.borderSubtle,
                        child: Text(
                          _isDebtType(_activeType)
                              ? 'Aucun remboursement pour le moment.'
                              : 'Aucun objectif pour le moment.',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (filtered.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (urgent.isNotEmpty)
                            buildSection(
                              title: 'Urgence (rouge)',
                              subtitle:
                                  'Echeance tres proche ou depassee avec ecart important.',
                              icon: Icons.priority_high_rounded,
                              accent: AppColors.danger,
                              sectionGoals: urgent,
                            ),
                          if (attention.isNotEmpty) ...[
                            if (urgent.isNotEmpty) const SizedBox(height: 10),
                            buildSection(
                              title: 'Attention (orange)',
                              subtitle:
                                  'Echeance qui approche: un ajustement est conseille.',
                              icon: Icons.warning_amber_rounded,
                              accent: AppColors.warning,
                              sectionGoals: attention,
                            ),
                          ],
                          if (regular.isNotEmpty) ...[
                            if (urgent.isNotEmpty || attention.isNotEmpty)
                              const SizedBox(height: 10),
                            buildSection(
                              title: 'En cours',
                              subtitle:
                                  'Progression normale, tries par date de cible.',
                              icon: Icons.timelapse_rounded,
                              accent: typeColor,
                              sectionGoals: regular,
                            ),
                          ],
                          if (achieved.isNotEmpty) ...[
                            if (urgent.isNotEmpty ||
                                attention.isNotEmpty ||
                                regular.isNotEmpty)
                              const SizedBox(height: 10),
                            buildSection(
                              title: 'Atteints',
                              subtitle:
                                  'Objectifs finalises, gardes ici pour suivi et historique.',
                              icon: Icons.verified_rounded,
                              accent: AppColors.primary,
                              sectionGoals: achieved,
                            ),
                          ],
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

class _OverviewMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _OverviewMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(185),
        borderRadius: BorderRadius.circular(AppRadius.r10),
        border: Border.all(color: accent.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accent.withAlpha(22),
              borderRadius: BorderRadius.circular(AppRadius.r8),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalsSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Widget child;

  const _GoalsSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      radius: AppRadius.r16,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      borderColor: accent.withAlpha(70),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent.withAlpha(20),
                  borderRadius: BorderRadius.circular(AppRadius.r8),
                ),
                child: Icon(icon, size: 16, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
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
  final _GoalAlertAssessment alert;
  final double? monthlyMarginAvailable;
  final VoidCallback onEdit;
  final VoidCallback onMove;
  final VoidCallback onHistory;
  final VoidCallback onArchive;

  const _GoalCard({
    required this.goal,
    required this.alert,
    required this.monthlyMarginAvailable,
    required this.onEdit,
    required this.onMove,
    required this.onHistory,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final isDebt = _isDebtType(goal.goalType);
    final isAchieved = _isAchievedStatus(goal.status);
    final daysToTarget = _daysUntil(goal.targetDate);
    final isCritical =
        alert.level == _GoalAlertLevel.overdue ||
        alert.level == _GoalAlertLevel.critical;
    final isAttention = alert.level == _GoalAlertLevel.attention;
    final statusColor = alert.color;
    final progress = (goal.progressPercent / 100).clamp(0.0, 1.0);
    final projected = goal.projectedDate;
    final typeColor = isDebt ? AppColors.danger : AppColors.primary;
    final progressColor = isAchieved
        ? AppColors.primary
        : isCritical
        ? AppColors.danger
        : isAttention
        ? AppColors.warning
        : typeColor;
    final cardBackground = isAchieved
        ? const Color(0xFFF1FAEE)
        : isCritical
        ? const Color(0xFFFFF5F5)
        : isAttention
        ? const Color(0xFFFFFAF0)
        : const Color(0xFFFAFCF8);
    final deadlineColor = isAchieved
        ? AppColors.primary
        : daysToTarget < 0
        ? AppColors.danger
        : daysToTarget <= 7
        ? AppColors.danger
        : daysToTarget <= 30
        ? AppColors.warning
        : AppColors.info;
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
    final style = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      visualDensity: VisualDensity.compact,
    );

    Widget badge(String text, Color color, {IconData? icon}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(AppRadius.r8),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
            ],
            Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    return AppPanel(
      backgroundColor: cardBackground,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: AppRadius.r16,
      borderColor: progressColor.withAlpha(110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: progressColor.withAlpha(22),
                  borderRadius: BorderRadius.circular(AppRadius.r10),
                ),
                child: Icon(
                  isDebt ? Icons.payments_rounded : Icons.savings_rounded,
                  color: progressColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.name,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        badge(
                          _typeLabel(goal.goalType),
                          typeColor,
                          icon: isDebt
                              ? Icons.account_balance_wallet_rounded
                              : Icons.flag_rounded,
                        ),
                        badge(alert.label, statusColor, icon: alert.icon),
                        badge(
                          _deadlineLabel(goal),
                          deadlineColor,
                          icon: Icons.event_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${goal.progressPercent.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: progressColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      height: 1.0,
                    ),
                  ),
                  const Text(
                    'complete',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(170),
              borderRadius: BorderRadius.circular(AppRadius.r10),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  'Actuel ${AppFormats.currencyCompact.format(goal.currentAmount)} / Cible ${AppFormats.currencyCompact.format(goal.targetAmount)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  isDebt
                      ? 'Reste a rembourser ${AppFormats.currencyCompact.format(goal.remainingAmount)}'
                      : 'Reste ${AppFormats.currencyCompact.format(goal.remainingAmount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: isAchieved
                        ? AppColors.primary
                        : isDebt
                        ? AppColors.danger
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.r8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: const Color(0xFFE7ECF3),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
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
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              badge(
                '${isDebt ? 'Mensuel remboursement' : 'Mensuel actuel'}: ${AppFormats.currencyCompact.format(goal.monthlyContribution)}',
                AppColors.textSecondary,
                icon: Icons.repeat_rounded,
              ),
              if (goal.autoContributionEnabled && goal.monthlyContribution > 0)
                badge(
                  goal.autoContributionStartDate == null
                      ? (isDebt ? 'Paiement auto actif' : 'Depot auto actif')
                      : (isDebt
                            ? 'Auto le ${goal.autoContributionStartDate!.day} de chaque mois'
                            : 'Depot le ${goal.autoContributionStartDate!.day} de chaque mois'),
                  AppColors.primary,
                  icon: Icons.bolt_rounded,
                ),
              badge(
                'Recommande: ${AppFormats.currencyCompact.format(goal.recommendedMonthly)}',
                AppColors.textPrimary,
                icon: Icons.calculate_rounded,
              ),
              badge(
                'Mois restants: ${goal.monthsRemaining}',
                AppColors.textSecondary,
                icon: Icons.date_range_rounded,
              ),
              badge(
                projected == null
                    ? 'Projection: non calculee'
                    : 'Projection: ${projected.month.toString().padLeft(2, '0')}.${projected.year}',
                AppColors.textSecondary,
                icon: Icons.auto_graph_rounded,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onMove,
                icon: Icon(
                  isDebt ? Icons.credit_score_rounded : Icons.sync_alt_rounded,
                  size: 16,
                ),
                style: style,
                label: Text(isDebt ? 'Paiement' : 'Depot / Retrait'),
              ),
              OutlinedButton.icon(
                onPressed: onHistory,
                icon: const Icon(Icons.history_rounded, size: 16),
                style: style,
                label: const Text('Historique'),
              ),
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded, size: 16),
                style: style,
                label: const Text('Modifier'),
              ),
              TextButton.icon(
                onPressed: onArchive,
                icon: const Icon(Icons.archive_rounded, size: 16),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                label: Text(goal.isArchived ? 'Desarchiver' : 'Archiver'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
