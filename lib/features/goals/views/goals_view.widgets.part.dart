part of 'goals_view.dart';


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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final goal = widget.goal;
    final alert = widget.alert;

    final isDebt = _isDebtType(goal.goalType);
    final isAchieved = _isAchievedStatus(goal.status);
    final daysToTarget = _daysUntil(goal.targetDate);
    final isCritical =
        alert.level == _GoalAlertLevel.overdue ||
        alert.level == _GoalAlertLevel.critical;
    final isAttention = alert.level == _GoalAlertLevel.attention;
    final progressColor = isAchieved
        ? AppColors.primary
        : isCritical
        ? AppColors.danger
        : isAttention
        ? AppColors.warning
        : (isDebt ? AppColors.danger : AppColors.primary);

    final accentColor = progressColor;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(8) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withAlpha(isDark ? 36 : 18),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Top accent bar ────────────────────────────
          Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentColor, accentColor.withAlpha(80)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Title + icon row ───────────────────
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        goal.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isDebt ? Icons.credit_card_rounded : Icons.savings_rounded,
                      size: 16,
                      color: isDark ? Colors.white30 : Colors.black26,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ─── Donut centré ───────────────────────
                Center(
                  child: GoalProgressDonut(
                    percent: goal.progressPercent,
                    size: 140,
                    color: progressColor,
                    strokeWidth: 11,
                    centerLabel: '${goal.progressPercent.round()}%',
                  ),
                ),
                const SizedBox(height: 20),

                // ─── Badges (alerte + deadline) ─────────
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Badge(text: alert.label, color: accentColor, icon: alert.icon),
                    _Badge(
                      text: _deadlineLabel(goal),
                      color: isAchieved
                          ? AppColors.primary
                          : (daysToTarget <= 7 ? AppColors.danger : Colors.amber),
                      icon: Icons.event_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ─── Actuel / Cible / Reste ─────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${AppFormats.formatFromChfCompact(goal.currentAmount)} / ${AppFormats.formatFromChfCompact(goal.targetAmount)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white38 : Colors.black45,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'Reste ${AppFormats.formatFromChfCompact(goal.remainingAmount)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white70 : Colors.black.withAlpha(188),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ─── Barre de progression linéaire ──────
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (goal.progressPercent / 100).clamp(0.0, 1.0),
                    backgroundColor: isDark ? Colors.white10 : Colors.black.withAlpha(25),
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 16),

                // ─── Actions bar ─────────────────────────
                Row(
                  children: [
                    _IconButton(icon: Icons.history_rounded, onTap: widget.onHistory),
                    const SizedBox(width: 8),
                    _IconButton(icon: Icons.edit_rounded, onTap: widget.onEdit),
                    const SizedBox(width: 8),
                    _IconButton(
                      icon: goal.isArchived ? Icons.unarchive_rounded : Icons.archive_rounded,
                      onTap: widget.onArchive,
                      isDanger: true,
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _expanded ? 'Moins' : 'Détails',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white54 : Colors.black45,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                            size: 14,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: widget.onMove,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Icon(
                        isDebt ? Icons.credit_score_rounded : Icons.sync_alt_rounded,
                        size: 18,
                      ),
                    ),
                  ],
                ),

                // ─── DétailsExpandables ──────────────────
                if (_expanded) ...[
                  const SizedBox(height: 14),
                  Container(
                    height: 1,
                    color: isDark ? Colors.white.withAlpha(14) : Colors.black.withAlpha(10),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _DetailBadge(
                        label: '${isDebt ? AppStrings.goals.monthlyRepayment : AppStrings.goals.monthlyCurrent} ${AppFormats.formatFromChfCompact(goal.monthlyContribution)}',
                        icon: Icons.repeat_rounded,
                      ),
                      if (goal.autoContributionEnabled && goal.monthlyContribution > 0)
                        _DetailBadge(
                          label: goal.autoContributionStartDate == null
                              ? (isDebt ? AppStrings.goals.autoPaymentActive : AppStrings.goals.autoDepositActive)
                              : (isDebt ? AppStrings.goals.autoPaymentDay(goal.autoContributionStartDate!.day) : AppStrings.goals.autoDepositDay(goal.autoContributionStartDate!.day)),
                          icon: Icons.bolt_rounded,
                          color: AppColors.primary,
                        ),
                      _DetailBadge(
                        label: AppStrings.goals.recommended(AppFormats.formatFromChfCompact(goal.recommendedMonthly)),
                        icon: Icons.calculate_rounded,
                      ),
                      _DetailBadge(
                        label: AppStrings.goals.monthsRemainingCount(goal.monthsRemaining),
                        icon: Icons.date_range_rounded,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalCardsGrid extends StatelessWidget {
  final List<Widget> children;

  const _GoalCardsGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double spacing = 16.0;
        const double maxCardWidth = 360.0;
        
        int columns = (constraints.maxWidth + spacing) ~/ (maxCardWidth + spacing);
        if (columns < 1) columns = 1;
        
        final double itemWidth = (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children.map((child) {
            return SizedBox(
              width: itemWidth,
              child: child,
            );
          }).toList(),
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const _Badge({required this.text, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ],
          Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDanger;

  const _IconButton({required this.icon, required this.onTap, this.isDanger = false});

  @override
  Widget build(BuildContext context) {
    final color = isDanger ? AppColors.danger : AppColors.textSecondary;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDanger ? AppColors.danger.withAlpha(isDark ? 50 : 30) : Colors.transparent;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isDanger ? Colors.transparent : AppColors.borderSubtle),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

class _DetailBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;

  const _DetailBadge({required this.label, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

