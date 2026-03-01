part of 'budget_view.dart';

extension _BudgetViewLogic on _BudgetViewState {
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
    _withState(() {
      _useGrossIncomeBase = grossMode;
      _draftDisposableIncome = value;
      _draftError = null;
      if (markDirty) _dirty = true;
    });
  }

  void _toggleLock(_RenderedGroup row) {
    _withState(() {
      if (_unlockedGroupIds.contains(row.group.groupId)) {
        _unlockedGroupIds.remove(row.group.groupId);
      } else {
        _unlockedGroupIds.add(row.group.groupId);
      }
    });
  }

  void _syncDraft(BudgetStats stats, {bool force = false}) {
    final token =
        '${stats.selectedYear}-${stats.selectedMonth}-${stats.budgetPlan.id}';
    if (!force && _draftToken == token) return;

    _draftToken = token;
    _useGrossIncomeBase = stats.budgetPlan.useGrossIncomeBase;
    final stored = stats.budgetPlan.forecastDisposableIncome;
    // If no income has been set yet, compute a sensible default
    _draftDisposableIncome = stored > 0
        ? stored
        : _recommendedDisposableInput(stats, gross: _useGrossIncomeBase);
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
          // Minimum = already-paid only (pending can still be adjusted/cancelled)
          final paidAmount =
              group.spentActual.clamp(0, double.infinity).toDouble();
          final plannedAmountRaw = draft.inputMode == 'amount'
              ? draft.amount
              : disposable * draft.percent / 100;
          final plannedAmount = plannedAmountRaw;
          final plannedPercent = disposable > 0
              ? (plannedAmount / disposable) * 100
              : (plannedAmount > 0 ? 100.0 : 0.0);
          final minAllowedPercent = disposable > 0
              ? (paidAmount / disposable) * 100
              : (paidAmount > 0 ? 100.0 : 0.0);

        return _RenderedGroup(
            group: group,
            draft: draft,
            plannedPercent: plannedPercent.clamp(0, double.infinity),
            plannedAmount: plannedAmount.clamp(0, double.infinity),
            minAllowedPercent: 0.0,
            minAllowedAmount: 0.0,
            maxAllowedPercent: 100,
            maxAllowedAmount: disposable > committedAmount
                ? disposable
                : committedAmount,
            isLocked: (paidAmount > plannedAmount) &&
                !_unlockedGroupIds.contains(group.groupId),
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

    final rows = baseRows.map<_RenderedGroup>((row) {
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
        isLocked: row.isLocked,
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
    _withState(() {
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
    _withState(() {
      _dirty = true;
      _draftError = null;
      if (current.inputMode == 'amount') {
        final clamped = value
            .clamp(row.minAllowedAmount, row.maxAllowedAmount)
            .toDouble();
        _drafts[row.group.groupId] = current.copyWith(amount: clamped);
        if (value > clamped + 0.0001 || value + 0.0001 < clamped) {
          _draftError =
              'Plage autorisee pour ${row.group.groupName}: ${AppFormats.formatFromChfCompact(row.minAllowedAmount)} - ${AppFormats.formatFromChfCompact(row.maxAllowedAmount)}';
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
        return AppStrings.budget.saveErrorServer;
      }
    }
    return AppStrings.budget.saveError;
  }

  Future<void> _savePlan(BudgetStats stats, _PlanTotals totals) async {
    if (totals.overLimit) {
      _withState(() {
        _draftError = AppStrings.budget.totalExceeds;
      });
      return;
    }
    _withState(() {
      _savingPlan = true;
      _draftError = null;
    });
    try {
      final month = _monthStart(ref.read(selectedBudgetMonthProvider));
      final rows = _buildRenderedGroups(stats);
      final api = ref.read(budgetPlanApiProvider);
      final groups = rows
          .map(
            (r) => BudgetPlanGroupUpdate(
              groupId: r.group.groupId,
              inputMode: r.draft.inputMode,
              plannedPercent: r.plannedPercent,
              plannedAmount: r.plannedAmount,
              priority: r.draft.priority,
            ),
          )
          .toList();
      final forecastIncome =
          (_draftDisposableIncome ?? stats.budgetPlan.forecastDisposableIncome)
              .toDouble();

      // Save the month plan
      await api.upsertPlan(
        year: month.year,
        month: month.month,
        forecastDisposableIncome: forecastIncome,
        useGrossIncomeBase: _useGrossIncomeBase,
        groups: groups,
      );

      // Optionally save as template
      if (_saveAsTemplateChecked) {
        await api.saveAsTemplate(
          forecastDisposableIncome: forecastIncome,
          useGrossIncomeBase: _useGrossIncomeBase,
          groups: groups,
        );
      }

      if (_saveAsTemplateChecked) {
        ref.invalidate(budgetStatsProvider);
      } else {
        ref.invalidate(
          budgetStatsProvider(
            BudgetMonthKey(year: month.year, month: month.month),
          ),
        );
      }
      final wasTemplate = _saveAsTemplateChecked;
      _withState(() {
        _dirty = false;
        _saveAsTemplateChecked = false;
      });
      if (mounted) {
        FocusManager.instance.primaryFocus?.unfocus();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wasTemplate
                  ? '${AppStrings.budget.planSaved} · Défini comme modèle récurrent ⭐'
                  : AppStrings.budget.planSaved,
            ),
          ),
        );
      }
    } catch (error, stack) {
      debugPrint('Erreur lors de la sauvegarde: $error\n$stack');
      if (error is DioException) {
        debugPrint('Détail Dio: ${error.response?.data}');
      }
      _withState(() {
        _draftError = _saveErrorMessage(error);
      });
    } finally {
      if (mounted) {
        _withState(() {
          _savingPlan = false;
        });
      }
    }
  }

  Future<void> _deleteTemplate(BudgetStats stats) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le modèle récurrent'),
        content: const Text(
          'Le modèle sera supprimé. Les mois déjà configurés ne seront pas affectés, mais les nouveaux mois ne seront plus initialisés automatiquement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.common.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final api = ref.read(budgetPlanApiProvider);
      await api.deleteTemplate();
      ref.invalidate(budgetStatsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Modèle récurrent supprimé')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la suppression du modèle')),
        );
      }
    }
  }

  Future<void> _changeMonth(int delta) async {
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppStrings.budget.changeMonthTitle),
          content: Text(AppStrings.budget.unsavedChangesLost),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppStrings.common.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppStrings.budget.continueAction),
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
        SnackBar(content: Text(AppStrings.budget.needPositiveIncome)),
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
            title: Text(AppStrings.budget.createSavingsGoalTitle),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.budget.savingsBudgetDesc,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    onChanged: (_) => setLocalState(() {}),
                    decoration: InputDecoration(
                      labelText: AppStrings.budget.goalNameLabel,
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
                    decoration: InputDecoration(
                      labelText: AppStrings.budget.goalPercentLabel,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: monthsCtrl,
                    onChanged: (_) => setLocalState(() {}),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: AppStrings.budget.goalHorizonLabel,
                    ),
                  ),
                  const SizedBox(height: 12),
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
                          AppStrings.budget.monthlyAmountLabel(
                            AppFormats.formatFromChfCompact(monthly),
                            pct.toStringAsFixed(1),
                          ),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppStrings.budget.goalTargetLabel(
                            AppFormats.formatFromChfCompact(target),
                            validMonths,
                            AppStrings.common.monthsFull[targetDate.month - 1],
                            targetDate.year,
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
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(AppStrings.common.cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(AppStrings.forms.create),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;

    final goalName = nameCtrl.text.trim().isEmpty
        ? AppStrings.budget.defaultGoalName
        : nameCtrl.text.trim();
    final pct = _parseNumber(percentCtrl.text).clamp(0, 100).toDouble();
    final months = (int.tryParse(monthsCtrl.text.trim()) ?? 12).clamp(1, 120);
    final monthly = disposableIncome * pct / 100;

    if (monthly <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.budget.needPositivePercent)),
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
            AppStrings.budget.goalCreated(
              goalName,
              AppFormats.formatFromChfCompact(monthly),
            ),
          ),
          action: SnackBarAction(
            label: AppStrings.budget.openGoals,
            onPressed: () => context.go('/goals'),
          ),
        ),
      );
    } on DioException catch (error) {
      final data = error.response?.data;
      final message = data is Map<String, dynamic> && data['error'] is String
          ? data['error'] as String
          : AppStrings.budget.createGoalError;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
