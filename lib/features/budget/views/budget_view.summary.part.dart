part of 'budget_view.dart';

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
        '${AppStrings.common.monthsFull[selectedMonth.month - 1]} ${selectedMonth.year}';

    final actions = Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (dirty)
          Text(
            AppStrings.budget.unsavedChanges,
            style: const TextStyle(
              color: AppColors.warningStrong,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        OutlinedButton(
          onPressed: onReset,
          child: Text(AppStrings.budget.reload),
        ),
        ElevatedButton.icon(
          onPressed: saving ? null : onSave,
          icon: saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined, size: 18),
          label: Text(saving ? AppStrings.budget.saving : AppStrings.budget.save),
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
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.r10),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Text(
              AppStrings.budget.step1Desc(
                AppFormats.formatFromChfCompact(netRecommendedInput),
                AppFormats.formatFromChfCompact(grossReferenceIncome),
                AppFormats.formatFromChfCompact(manualCommittedAmount),
                AppFormats.formatFromChfCompact(autoAmount),
              ),
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
              Text(
                AppStrings.budget.basePlan,
                style: const TextStyle(
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
                    ? AppStrings.budget.modeGross
                    : AppStrings.budget.modeNet,
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
                      Text(
                        AppStrings.budget.showGross,
                        style: const TextStyle(
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
                  AppStrings.budget.autoReservedAmount(
                    AppFormats.formatFromChfCompact(autoAmount),
                    autoPercent.toStringAsFixed(1),
                  ),
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
                  AppStrings.budget.copiedFrom(
                    AppStrings.common.monthsFull[copiedFrom!.month - 1],
                    copiedFrom!.year,
                  ),
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
              Text(
                AppStrings.budget.alreadyAllocated,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                AppStrings.budget.manualPctLabel(
                  manualPercent.toStringAsFixed(1),
                  manualCapacityPercent.toStringAsFixed(1),
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                AppStrings.budget.alreadyDistributed(
                  AppFormats.formatFromChfCompact(totalAmount),
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.danger,
                ),
              ),
              Text(
                AppStrings.budget.stillFree(
                  remainingAmount >= 0
                      ? AppFormats.formatFromChfCompact(remainingAmount)
                      : '0',
                ),
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
            AppStrings.budget.step2Desc(
              AppFormats.formatFromChfCompact(manualCapacityAmount),
              AppFormats.formatFromChfCompact(manualAmount),
            ) + (remainingPercent < 0 ? AppStrings.budget.step2Deficit : ''),
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
            AppStrings.budget.step3Desc(
              AppFormats.formatFromChfCompact(fullyNetAvailable),
            ),
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
              backgroundColor: AppColors.surfaceInfoSoft,
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
      borderColor: AppColors.borderSuccess,
      backgroundColor: AppColors.surfaceSuccess,
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
                Text(
                  AppStrings.budget.savingsMonthly,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  canCreate
                      ? AppStrings.budget.savingsMonthlyDesc
                      : AppStrings.budget.savingsMonthlyNoIncome,
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
            child: Text(AppStrings.budget.goToGoals),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: canCreate ? onCreateGoal : null,
            icon: const Icon(Icons.add, size: 16),
            label: Text(AppStrings.budget.createSavings),
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

  Widget _buildAutoBadge(
    String text, {
    Color textColor = AppColors.textPrimary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.r10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = groups.take(6).toList();
    final remaining = groups.length - visible.length;

    return AppPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      radius: AppRadius.r16,
      borderColor: AppColors.borderSuccessSoft,
      backgroundColor: AppColors.surfaceSuccessSoft,
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
              Expanded(
                child: Text(
                  AppStrings.budget.autoReserved,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${AppFormats.formatFromChfCompact(autoAmount)} - ${autoPercent.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            AppStrings.budget.autoReservedDesc,
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
                  _buildAutoBadge(
                    '${g.groupName}: ${AppFormats.formatFromChfCompact(g.autoPlannedAmount)}',
                  ),
                if (remaining > 0)
                  _buildAutoBadge(
                    AppStrings.budget.moreOthers(remaining),
                    textColor: AppColors.textSecondary,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
