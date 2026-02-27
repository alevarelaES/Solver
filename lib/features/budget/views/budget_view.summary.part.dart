part of 'budget_view.dart';



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
  // Top-bar
  final DateTime selectedMonth;
  final bool dirty;
  final bool saving;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final VoidCallback? onSave;
  final VoidCallback onReset;

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
    final overLimit = totalPercent > 100.0001;
    final ratio = (totalPercent / 100).clamp(0.0, 1.0);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final monthLabel =
        '${AppStrings.common.monthsFull[selectedMonth.month - 1]} ${selectedMonth.year}';

    final monthNav = Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceHeader,
        borderRadius: BorderRadius.circular(AppRadius.r10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: IconButton(
              onPressed: onPrevMonth,
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.chevron_left_rounded, size: 16),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              monthLabel,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            width: 28,
            height: 28,
            child: IconButton(
              onPressed: onNextMonth,
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.chevron_right_rounded, size: 16),
            ),
          ),
        ],
      ),
    );

    return AppPanel(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      radius: AppRadius.r24,
      borderColor: AppColors.borderSubtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              monthNav,
              const Spacer(),
              if (dirty)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(
                    AppStrings.budget.unsavedChanges,
                    style: const TextStyle(
                      color: AppColors.warningStrong,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              OutlinedButton(
                onPressed: onReset,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(AppStrings.budget.reload, style: const TextStyle(fontSize: 13)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: saving ? null : onSave,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: saving
                    ? const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, size: 16),
                label: Text(
                  saving ? AppStrings.budget.saving : AppStrings.budget.save,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.budget.basePlan,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 260,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.r12),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: _SyncedNumericField(
                      key: ValueKey('disposable-$inputVersion'),
                      valueText: _editableInputValue(disposable, maxDecimals: 0),
                      onChanged: onDisposableChanged,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
                      ],
                      decoration: InputDecoration(
                        prefixText: '${AppFormats.currencySymbol} ',
                        prefixStyle: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                        hintText: '0',
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                   Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppStrings.budget.showGross,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: useGrossIncomeBase,
                        onChanged: onUseGrossIncomeBaseChanged,
                        activeTrackColor: AppColors.primary,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (copiedFrom != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWarningSoft,
                        borderRadius: BorderRadius.circular(AppRadius.r20),
                      ),
                      child: Text(
                        AppStrings.budget.copiedFrom(
                          AppStrings.common.monthsFull[copiedFrom!.month - 1],
                          copiedFrom!.year,
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warningStrong,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${totalPercent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        letterSpacing: -1,
                        color: overLimit ? AppColors.danger : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppStrings.budget.alreadyAllocated,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppStrings.budget.alreadyDistributed(
                      AppFormats.formatFromChfCompact(totalAmount),
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppStrings.budget.stillFree(
                      remainingAmount >= 0
                          ? AppFormats.formatFromChfCompact(remainingAmount)
                          : '0',
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: remainingAmount >= 0 ? AppColors.success : AppColors.danger,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.r12),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 16,
              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.surfaceInfoSoft,
              valueColor: AlwaysStoppedAnimation<Color>(
                overLimit ? AppColors.danger : AppColors.primary,
              ),
            ),
          ),
          if (autoAmount > 0) ...[
            const SizedBox(height: 16),
            Text(
              AppStrings.budget.autoReservedAmount(
                AppFormats.formatFromChfCompact(autoAmount),
                autoPercent.toStringAsFixed(1),
              ),
              style: TextStyle(
                fontSize: 13,
                color: autoPercent > 100 ? AppColors.danger : AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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
