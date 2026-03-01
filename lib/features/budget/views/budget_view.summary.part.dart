part of 'budget_view.dart';



class _HalfDonutGauge extends StatelessWidget {
  final double ratio;
  final Color activeColor;
  final Color inactiveColor;

  const _HalfDonutGauge({super.key, required this.ratio, required this.activeColor, required this.inactiveColor});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(160, 80),
      painter: _HalfDonutPainter(ratio: ratio, activeColor: activeColor, inactiveColor: inactiveColor),
    );
  }
}

class _HalfDonutPainter extends CustomPainter {
  final double ratio;
  final Color activeColor;
  final Color inactiveColor;

  _HalfDonutPainter({required this.ratio, required this.activeColor, required this.inactiveColor});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 14.0;
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      (size.height * 2) - strokeWidth,
    );

    final bgPaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 3.141592653589793, 3.141592653589793, false, bgPaint);
    canvas.drawArc(rect, 3.141592653589793, 3.141592653589793 * ratio.clamp(0.001, 1.0), false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _HalfDonutPainter old) =>
      ratio != old.ratio || activeColor != old.activeColor || inactiveColor != old.inactiveColor;
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
  final bool hasTemplate;
  final bool saveAsTemplate;
  final ValueChanged<bool> onSaveAsTemplateChanged;
  final VoidCallback onDeleteTemplate;
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
    required this.hasTemplate,
    required this.saveAsTemplate,
    required this.onSaveAsTemplateChanged,
    required this.onUseGrossIncomeBaseChanged,
    required this.onDisposableChanged,
    required this.selectedMonth,
    required this.dirty,
    required this.saving,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onSave,
    required this.onReset,
    required this.onDeleteTemplate,
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

    return PremiumCardBase(
      variant: PremiumCardVariant.standard,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              monthNav,
              const SizedBox(width: 20),
              Text(
                AppStrings.budget.basePlan,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 8),
              Container(
                width: 160,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.r8),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                child: _SyncedNumericField(
                  key: ValueKey('disposable-$inputVersion'),
                  valueText: _editableInputValue(disposable, maxDecimals: 0),
                  onChanged: onDisposableChanged,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]'))],
                  decoration: InputDecoration(
                    prefixText: '${AppFormats.currencySymbol} ',
                    prefixStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    hintText: '0',
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (copiedFrom != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWarningSoft,
                    borderRadius: BorderRadius.circular(AppRadius.r12),
                  ),
                  child: Text(
                    AppStrings.budget.copiedFrom(AppStrings.common.monthsFull[copiedFrom!.month - 1], copiedFrom!.year),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.warningStrong),
                  ),
                ),
              ],
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(AppStrings.budget.showGross, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  Switch(
                    value: useGrossIncomeBase,
                    onChanged: onUseGrossIncomeBaseChanged,
                    activeTrackColor: AppColors.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              const SizedBox(width: 16),
              if (dirty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(AppStrings.budget.unsavedChanges, style: const TextStyle(color: AppColors.warningStrong, fontWeight: FontWeight.w700, fontSize: 11)),
                ),
              Tooltip(
                message: 'Modifications non enregistrées – rechargez pour annuler',
                child: IconButton(
                  onPressed: onReset,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              const SizedBox(width: 8),
              if (hasTemplate)
                Tooltip(
                  message: 'Supprimer le modèle récurrent actuel',
                  child: IconButton(
                    onPressed: onDeleteTemplate,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    color: AppColors.danger,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                ),
              // Template checkbox
              Tooltip(
                message: hasTemplate
                    ? 'Un modèle récurrent est déjà actif ⭐. Cochez pour le mettre à jour avec ce plan.'
                    : 'Cochez pour utiliser ce plan comme point de départ pour les prochains mois.',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: saveAsTemplate,
                        onChanged: (v) => onSaveAsTemplateChanged(v ?? false),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        activeColor: AppColors.primary,
                        side: BorderSide(
                          color: saveAsTemplate ? AppColors.primary : AppColors.borderSubtle,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      hasTemplate ? '⭐ Modèle' : 'Définir modèle',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: saveAsTemplate ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: saving
                    ? Container(
                        key: const ValueKey('saving'),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(80),
                          borderRadius: BorderRadius.circular(AppRadius.r10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                            const SizedBox(width: 8),
                            Text(AppStrings.budget.saving, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                          ],
                        ),
                      )
                    : GestureDetector(
                        key: const ValueKey('save'),
                        onTap: onSave,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: onSave == null ? AppColors.textDisabled : AppColors.primary,
                            borderRadius: BorderRadius.circular(AppRadius.r10),
                            boxShadow: onSave == null ? null : [
                              BoxShadow(color: AppColors.primary.withAlpha(80), blurRadius: 8, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.save_alt_rounded, size: 14, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(AppStrings.budget.save, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: autoAmount > 0 ? Tooltip(
                  message: 'Prélèvements automatiques planifiés : factures récurrentes déjà payées ou en attente de paiement ce mois-ci.',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceWarningSoft,
                          borderRadius: BorderRadius.circular(AppRadius.r8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt_rounded, size: 13, color: AppColors.warningStrong),
                            const SizedBox(width: 4),
                            Text(
                              '${AppFormats.formatFromChfCompact(autoAmount)} déjà engagés',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.warningStrong),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.textSecondary),
                    ],
                  ),
                ) : const SizedBox(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    _HalfDonutGauge(
                      ratio: ratio, 
                      activeColor: overLimit ? AppColors.danger : AppColors.primary,
                      inactiveColor: isDark ? Colors.white.withAlpha(20) : AppColors.surfaceInfoSoft,
                    ),
                    Positioned(
                      bottom: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${totalPercent.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                              letterSpacing: -1,
                              color: overLimit ? AppColors.danger : AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppStrings.budget.alreadyAllocated,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      AppStrings.budget.alreadyDistributed(AppFormats.formatFromChfCompact(totalAmount)),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppStrings.budget.stillFree(remainingAmount >= 0 ? AppFormats.formatFromChfCompact(remainingAmount) : '0'),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: remainingAmount >= 0 ? AppColors.success : AppColors.danger),
                    ),
                  ],
                ),
              ),
            ],
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

    return PremiumCardBase(
      variant: PremiumCardVariant.standard,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      overrideBorder: AppColors.borderSuccess,
      overrideSurface: AppColors.surfaceSuccess.withValues(alpha: 0.1),
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

