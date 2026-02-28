part of 'goals_view.dart';

extension _GoalsViewLogic on _GoalsViewState {
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
              ? (isDebt
                    ? AppStrings.goals.newDebtTitle
                    : AppStrings.goals.newGoalTitle)
              : (isDebt
                    ? AppStrings.goals.editDebtTitle
                    : AppStrings.goals.editGoalTitle);
          final targetLabel = isDebt
              ? AppStrings.goals.debtAmountLabel(AppFormats.currencyCode)
              : AppStrings.goals.targetAmountLabel(AppFormats.currencyCode);
          final initialLabel = isDebt
              ? AppStrings.goals.alreadyRepaidLabel(AppFormats.currencyCode)
              : AppStrings.goals.initialAmountLabel(AppFormats.currencyCode);
          final monthlyLabel = isDebt
              ? AppStrings.goals.monthlyRepaymentLabel(AppFormats.currencyCode)
              : AppStrings.goals.monthlyContributionLabel(
                  AppFormats.currencyCode,
                );

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
                            label: Text(AppStrings.goals.typeLabelGoal),
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
                            label: Text(AppStrings.goals.typeLabelDebt),
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
                      decoration: InputDecoration(
                        labelText: AppStrings.goals.namePlaceholder,
                      ),
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
                            ? AppStrings.goals.autoPaymentMonthly
                            : AppStrings.goals.autoDepositMonthly,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        AppStrings.goals.autoDesc,
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
                          Text(
                            AppStrings.goals.firstAutoDate,
                            style: const TextStyle(
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
                                  ? AppStrings.goals.chooseDate
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
                      decoration: InputDecoration(
                        labelText: AppStrings.goals.priorityLabel,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          AppStrings.goals.targetDateLabel,
                          style: const TextStyle(
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
                      padding: const EdgeInsets.all(AppSpacing.s10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.r10),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.goals.recommendedForTarget(
                              AppFormats.formatFromChfCompact(recommendedMonthly.toDouble()),
                            ),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            projected == null
                                ? AppStrings.goals.projectedUnavailable
                                : AppStrings.goals.projectedWithMonthly(
                                    '${projected.month.toString().padLeft(2, '0')}.${projected.year}',
                                  ),
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
                child: Text(AppStrings.common.cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(AppStrings.common.save),
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
        ).showSnackBar(SnackBar(content: Text(AppStrings.goals.saved)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppStrings.goals.saveErrorMsg)));
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
            title: Text(AppStrings.goals.movementTitle(goal.name)),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Text(AppStrings.goals.deposit),
                          selected: isDeposit,
                          onSelected: (_) =>
                              setLocalState(() => isDeposit = true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Text(AppStrings.goals.withdrawal),
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
                      labelText: AppStrings.goals.amountLabel(AppFormats.currencyCode),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.s10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.r10),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.goals.availableNow(AppFormats.formatFromChfCompact(availableNow)),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isDeposit
                              ? AppStrings.goals.afterDeposit(AppFormats.formatFromChfCompact(projected))
                              : AppStrings.goals.afterWithdrawal(AppFormats.formatFromChfCompact(projected)),
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
                    decoration: InputDecoration(
                      labelText: AppStrings.goals.noteOptional,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(AppStrings.common.cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(AppStrings.goals.validate),
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
          ).showSnackBar(SnackBar(content: Text(AppStrings.goals.invalidAmount)));
        }
        return;
      }
      if (!isDeposit && amount > availableNow) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.goals.withdrawalExceedsAvailable)),
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
        ).showSnackBar(SnackBar(content: Text(AppStrings.goals.movementSaved)));
      }
    } catch (e) {
      String message = AppStrings.goals.movementError;
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
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppStrings.goals.historyTitle(goal.name),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(AppStrings.common.close),
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
                        error: (e, _) => Center(child: Text(AppStrings.goals.historyError(e))),
                        data: (entries) {
                          if (entries.isEmpty) {
                            return Center(
                              child: Text(AppStrings.goals.noMovements),
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
                                      (entry.isAuto
                                          ? AppStrings.goals.autoEntry
                                          : AppStrings.goals.manualEntry),
                                ),
                                trailing: Text(
                                  '${isPositive ? '+' : '-'} ${AppFormats.formatFromChfCompact(entry.amount.abs())}',
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

  Widget _buildGoalsView(BuildContext context) {
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

    return AppPageScaffold(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.s18,
        AppSpacing.xl,
        AppSpacing.xxxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppPageHeader(
            title: AppStrings.goals.title,
            subtitle: AppStrings.goals.subtitle,
          ),
          const SizedBox(height: AppSpacing.md),
          goalsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text(
              AppStrings.goals.historyError(e),
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

              Widget buildCard(SavingGoal goal) => _GoalCard(
                  goal: goal,
                  alert: goalAlerts[goal.id] ?? _assessGoalAlert(goal),
                  monthlyMarginAvailable: monthlyMarginAvailable,
                  onEdit: () => _showGoalEditor(goal: goal),
                  onMove: () => _showGoalEntryEditor(goal),
                  onHistory: () => _showGoalHistory(goal),
                  onArchive: () async {
                    await ref.read(goalsApiProvider).archiveGoal(
                          id: goal.id,
                          isArchived: !goal.isArchived,
                        );
                    ref.invalidate(goalsProvider);
                  },
                );
              // Sort filtered goals: priority 0 first, then by targetDate ascending.
              final sortedGoals = List<SavingGoal>.from(filtered)
                ..sort((a, b) {
                  // Priority 0 comes first
                  if (a.priority == 0 && b.priority != 0) return -1;
                  if (b.priority == 0 && a.priority != 0) return 1;
                  
                  // Then by target date ascending (closest deadline first)
                  if (a.targetDate == null && b.targetDate == null) return 0;
                  if (a.targetDate == null) return 1;
                  if (b.targetDate == null) return -1;
                  return a.targetDate!.compareTo(b.targetDate!);
                });

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(
                        width: 250,
                        child: GoalsTabBar(
                          selectedIndex: _isDebtType(_activeType) ? 1 : 0,
                          onChanged: (index) {
                            _withState(() {
                              _activeType = index == 0 ? 'savings' : 'debt';
                            });
                          },
                          tabs: const ['Objectifs', 'Remboursements'],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showGoalEditor(forcedType: _activeType),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(_isDebtType(_activeType) ? AppStrings.goals.newDebtTitle : AppStrings.goals.newGoalTitle),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GoalsDashboard(
                    cibleTotale: totalTarget,
                    capitalActuel: totalCurrent,
                    progressionPercent: averageProgress,
                    mensuelCumule: totalMonthly,
                    objectifsAtteints: achieved.length,
                    alertCounts: {
                      'Urgence': urgent.length + overdueCount,
                      'Attention': attention.length,
                    },
                  ),
                  const SizedBox(height: 20),
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
                            ? AppStrings.goals.noDebts
                            : AppStrings.goals.noGoalsList,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (filtered.isNotEmpty)
                    _GoalCardsGrid(
                      children: sortedGoals.map((g) => buildCard(g)).toList(),
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
