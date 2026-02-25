part of 'goals_view.dart';

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
            padding: const EdgeInsets.all(AppSpacing.s6),
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

class _GoalCard extends StatefulWidget {
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
  State<_GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<_GoalCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;
    final alert = widget.alert;

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
        ? AppColors.surfaceSuccess
        : isCritical
        ? AppColors.surfaceDangerSoft
        : isAttention
        ? AppColors.surfaceWarningSoft
        : AppColors.surfaceNeutralSoft;
    final deadlineColor = isAchieved
        ? AppColors.primary
        : daysToTarget < 0
        ? AppColors.danger
        : daysToTarget <= 7
        ? AppColors.danger
        : daysToTarget <= 30
        ? AppColors.warning
        : AppColors.info;
    final risk =
        isDebt ? _assessDebtRisk(goal, widget.monthlyMarginAvailable) : null;
    final delayText = risk == null
        ? null
        : risk.projectedDelayMonths == null
        ? AppStrings.goals.delayUnknown
        : AppStrings.goals.delayMonths(risk.projectedDelayMonths!);
    final marginText = risk == null
        ? null
        : risk.marginAfterPayment == null
        ? AppStrings.goals.marginUnavailable
        : risk.marginAfterPayment! >= 0
        ? AppStrings.goals.marginAfterPayment(
            AppFormats.formatFromChfCompact(risk.marginAfterPayment!),
          )
        : AppStrings.goals.marginAfterPayment(
            '-${AppFormats.formatFromChfCompact(risk.marginAfterPayment!.abs())}',
          );

    // ── Reusable badge builder ────────────────────────────────────────────────
    Widget badge(String text, Color color, {IconData? icon}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color.withAlpha(16),
          borderRadius: BorderRadius.circular(AppRadius.r6),
          border: Border.all(color: color.withAlpha(55)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 4),
            ],
            Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ],
        ),
      );
    }

    // ── Icon-only button style ────────────────────────────────────────────────
    final iconBtnStyle = OutlinedButton.styleFrom(
      padding: const EdgeInsets.all(6),
      minimumSize: const Size(28, 28),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.r6),
      ),
    );
    final iconBtnDangerStyle = iconBtnStyle.copyWith(
      foregroundColor: WidgetStatePropertyAll(AppColors.danger),
      side: WidgetStatePropertyAll(
        BorderSide(color: AppColors.danger.withAlpha(80)),
      ),
    );

    return AppPanel(
      backgroundColor: cardBackground,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      radius: AppRadius.r12,
      borderColor: progressColor.withAlpha(65),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: icon + name + % ────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: progressColor.withAlpha(18),
                  borderRadius: BorderRadius.circular(AppRadius.r8),
                ),
                child: Icon(
                  isDebt ? Icons.payments_rounded : Icons.savings_rounded,
                  color: progressColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        goal.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    badge(alert.label, statusColor, icon: alert.icon),
                    const SizedBox(width: 4),
                    badge(
                      _deadlineLabel(goal),
                      deadlineColor,
                      icon: Icons.event_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${goal.progressPercent.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: progressColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    AppStrings.goals.completedLabel,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Amounts row ─────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(140),
              borderRadius: BorderRadius.circular(AppRadius.r8),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              runSpacing: 2,
              children: [
                Text(
                  AppStrings.goals.currentVsTarget(
                    AppFormats.formatFromChfCompact(goal.currentAmount),
                    AppFormats.formatFromChfCompact(goal.targetAmount),
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  isDebt
                      ? AppStrings.goals.remainingToRepay(
                          AppFormats.formatFromChfCompact(goal.remainingAmount),
                        )
                      : AppStrings.goals.remainingGoal(
                          AppFormats.formatFromChfCompact(goal.remainingAmount),
                        ),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
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
          const SizedBox(height: 7),

          // ── Progress bar ────────────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.r6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: AppColors.surfaceInfoSoft,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 8),

          // ── Action row ──────────────────────────────────────────────────────
          Row(
            children: [
              // Secondary actions: icon-only with tooltip
              Tooltip(
                message: AppStrings.goals.historyAction,
                child: OutlinedButton(
                  onPressed: widget.onHistory,
                  style: iconBtnStyle,
                  child: const Icon(Icons.history_rounded, size: 13),
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: AppStrings.common.edit,
                child: OutlinedButton(
                  onPressed: widget.onEdit,
                  style: iconBtnStyle,
                  child: const Icon(Icons.edit_rounded, size: 13),
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: goal.isArchived
                    ? AppStrings.goals.unarchiveAction
                    : AppStrings.goals.archiveAction,
                child: OutlinedButton(
                  onPressed: widget.onArchive,
                  style: iconBtnDangerStyle,
                  child: Icon(
                    goal.isArchived
                        ? Icons.unarchive_rounded
                        : Icons.archive_rounded,
                    size: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // "Voir détail" toggle
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _expanded ? 'Réduire' : 'Voir détail',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        _expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // Primary deposit / payment (icon-only, right-aligned)
              Tooltip(
                message: isDebt
                    ? AppStrings.goals.payment
                    : AppStrings.goals.depositWithdraw,
                child: ElevatedButton(
                  onPressed: widget.onMove,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.r8),
                    ),
                  ),
                  child: Icon(
                    isDebt
                        ? Icons.credit_score_rounded
                        : Icons.sync_alt_rounded,
                    size: 15,
                  ),
                ),
              ),
            ],
          ),

          // ── Expandable detail section ───────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: _expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          badge(
                            '${isDebt ? AppStrings.goals.monthlyRepayment : AppStrings.goals.monthlyCurrent}: ${AppFormats.formatFromChfCompact(goal.monthlyContribution)}',
                            AppColors.textSecondary,
                            icon: Icons.repeat_rounded,
                          ),
                          if (goal.autoContributionEnabled &&
                              goal.monthlyContribution > 0)
                            badge(
                              goal.autoContributionStartDate == null
                                  ? (isDebt
                                        ? AppStrings.goals.autoPaymentActive
                                        : AppStrings.goals.autoDepositActive)
                                  : (isDebt
                                        ? AppStrings.goals.autoPaymentDay(
                                            goal
                                                .autoContributionStartDate!.day,
                                          )
                                        : AppStrings.goals.autoDepositDay(
                                            goal
                                                .autoContributionStartDate!.day,
                                          )),
                              AppColors.primary,
                              icon: Icons.bolt_rounded,
                            ),
                          badge(
                            AppStrings.goals.recommended(
                              AppFormats.formatFromChfCompact(
                                goal.recommendedMonthly,
                              ),
                            ),
                            AppColors.textPrimary,
                            icon: Icons.calculate_rounded,
                          ),
                          badge(
                            AppStrings.goals.monthsRemainingCount(
                              goal.monthsRemaining,
                            ),
                            AppColors.textSecondary,
                            icon: Icons.date_range_rounded,
                          ),
                          badge(
                            projected == null
                                ? AppStrings.goals.projectionUnknown
                                : AppStrings.goals.projection(
                                    '${projected.month.toString().padLeft(2, '0')}.${projected.year}',
                                  ),
                            AppColors.textSecondary,
                            icon: Icons.auto_graph_rounded,
                          ),
                        ],
                      ),
                      if (risk != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
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
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
