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
            padding: const EdgeInsets.all(AppSpacing.lg),
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
      maxWidth: 1380,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.s18,
        AppSpacing.xl,
        AppSpacing.xxxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppPageHeader(
            title: 'Objectifs',
            subtitle:
                'Suivez vos objectifs d\'epargne et vos remboursements de dettes.',
          ),
          const SizedBox(height: AppSpacing.md),
          AppPanel(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            radius: AppRadius.r20,
            borderColor: AppColors.borderSubtle,
            child: goalsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
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
                              padding: const EdgeInsets.all(AppSpacing.s3),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceHeader,
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(AppRadius.r12),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _TypeButton(
                                    label: 'Objectifs',
                                    isActive: !_isDebtType(_activeType),
                                    activeColor: AppColors.primary,
                                    onTap: () => _withState(
                                      () => _activeType = 'savings',
                                    ),
                                  ),
                                  _TypeButton(
                                    label: 'Remboursements',
                                    isActive: _isDebtType(_activeType),
                                    activeColor: AppColors.danger,
                                    onTap: () =>
                                        _withState(() => _activeType = 'debt'),
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
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.s14,
                        AppSpacing.s14,
                        AppSpacing.s14,
                        AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            typeColor.withAlpha(24),
                            AppColors.surfaceMuted,
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
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(AppRadius.r8),
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
                                accent: AppColors.successStrong,
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
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(AppRadius.r10),
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
        ],
      ),
    );
  }
}
