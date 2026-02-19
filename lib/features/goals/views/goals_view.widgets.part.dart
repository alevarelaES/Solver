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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.s10,
        AppSpacing.md,
        AppSpacing.md,
      ),
      borderColor: accent.withAlpha(70),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.s6),
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
    final style =
        AppButtonStyles.outline(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ).copyWith(
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
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
              backgroundColor: AppColors.surfaceInfoSoft,
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
                style: AppButtonStyles.dangerOutline().copyWith(
                  textStyle: const WidgetStatePropertyAll(
                    TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
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
