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
      _withState(() {
        _draftError = 'Le total depasse 100%.';
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
      _withState(() {
        _dirty = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Plan budget enregistre')));
      }
    } catch (error) {
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
}
