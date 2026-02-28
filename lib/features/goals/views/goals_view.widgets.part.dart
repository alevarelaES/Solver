part of 'goals_view.dart';


class _GoalCard extends StatefulWidget {
  final SavingGoal goal;
  final _GoalAlertAssessment alert;
  final double? monthlyMarginAvailable;
  final VoidCallback onEdit;
  final VoidCallback onMove;
  final VoidCallback onHistory;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  const _GoalCard({
    required this.goal,
    required this.alert,
    required this.monthlyMarginAvailable,
    required this.onEdit,
    required this.onMove,
    required this.onHistory,
    required this.onArchive,
    required this.onDelete,
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 8),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withAlpha(8) : Colors.white.withAlpha(130),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white.withAlpha(20) : Colors.white.withAlpha(200),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

            // ─── Header : titre ───────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    goal.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 19,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: -0.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (goal.status == 'achieved' || goal.status == 'completed')
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.success.withAlpha(20) : AppColors.success.withAlpha(40),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? AppColors.success.withAlpha(50) : AppColors.success.withAlpha(80)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 12,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Terminé',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (goal.isArchived)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade400),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.archive_outlined,
                          size: 12,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Archivé',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // ─── Donut centré ─────────────────────────────────────
            Center(
              child: GoalProgressDonut(
                percent: goal.progressPercent,
                size: 160,
                color: progressColor,
                strokeWidth: 16,
                centerLabel: '${goal.progressPercent.round()}%',
              ),
            ),
            const SizedBox(height: 18),

            // ─── Badges (Alerte, Échéance, etc) ───────────────────
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                // Badge type (cochon / carte) — couleur accent
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  decoration: BoxDecoration(
                    color: accentColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: accentColor.withAlpha(55)),
                  ),
                  child: Icon(
                    isDebt ? Icons.credit_card_rounded : Icons.savings_rounded,
                    size: 14,
                    color: accentColor,
                  ),
                ),
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

            // ─── Actuel / Cible / Reste ───────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Actuel ${AppFormats.formatFromChfCompact(goal.currentAmount)} / ${AppFormats.formatFromChfCompact(goal.targetAmount)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Reste ${AppFormats.formatFromChfCompact(goal.remainingAmount)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ─── Barre de progression ─────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (goal.progressPercent / 100).clamp(0.0, 1.0),
                backgroundColor: isDark ? Colors.white24 : Colors.black.withAlpha(45),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 16),

            // ─── Actions bar ─────────────────────────────────────
            Row(
              children: [
                _IconButton(icon: Icons.history_rounded, tooltip: 'Historique', onTap: widget.onHistory),
                const SizedBox(width: 8),
                _IconButton(icon: Icons.edit_rounded, tooltip: 'Modifier', onTap: widget.onEdit),
                const SizedBox(width: 8),
                _IconButton(
                  tooltip: goal.isArchived ? 'Désarchiver' : 'Archiver',
                  icon: goal.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(goal.isArchived ? 'Désarchiver l\'objectif' : 'Archiver l\'objectif'),
                        content: Text(goal.isArchived ? 'Voulez-vous restaurer cet objectif dans les éléments en cours ?' : 'Voulez-vous archiver cet objectif ? Il sera déplacé vers l\'onglet Terminés.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(goal.isArchived ? 'Désarchiver' : 'Archiver'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      widget.onArchive();
                    }
                  },
                ),
                const SizedBox(width: 8),
                _IconButton(
                  tooltip: 'Supprimer',
                  icon: Icons.delete_outline_rounded,
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Supprimer l\'objectif'),
                        content: Text('Voulez-vous vraiment supprimer cet objectif de manière définitive ?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
                            child: const Text('Supprimer'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      widget.onDelete();
                    }
                  },
                  isDanger: true,
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _expanded ? 'Masquer' : 'Voir détail',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        size: 16,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: widget.onMove,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Icon(
                    isDebt ? Icons.credit_score_rounded : Icons.sync_alt_rounded,
                    size: 22,
                  ),
                ),
              ],
            ),

            // ─── Détails expandables ──────────────────────────────
            if (_expanded) ...[
              const SizedBox(height: 16),
              Container(
                height: 1,
                color: isDark ? Colors.white.withAlpha(14) : Colors.black.withAlpha(15),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DetailBadge(
                    label:
                        '${isDebt ? AppStrings.goals.monthlyRepayment : AppStrings.goals.monthlyCurrent} ${AppFormats.formatFromChfCompact(goal.monthlyContribution)}',
                    icon: Icons.repeat_rounded,
                  ),
                  if (goal.autoContributionEnabled && goal.monthlyContribution > 0)
                    _DetailBadge(
                      label: goal.autoContributionStartDate == null
                          ? (isDebt
                                ? AppStrings.goals.autoPaymentActive
                                : AppStrings.goals.autoDepositActive)
                          : (isDebt
                                ? AppStrings.goals.autoPaymentDay(
                                    goal.autoContributionStartDate!.day,
                                  )
                                : AppStrings.goals.autoDepositDay(
                                    goal.autoContributionStartDate!.day,
                                  )),
                      icon: Icons.bolt_rounded,
                      color: AppColors.primary,
                    ),
                  _DetailBadge(
                    label: AppStrings.goals.recommended(
                      AppFormats.formatFromChfCompact(goal.recommendedMonthly),
                    ),
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
      ),
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
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(text, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDanger;
  final String? tooltip;

  const _IconButton({required this.icon, required this.onTap, this.isDanger = false, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = isDanger
        ? AppColors.danger
        : (isDark ? Colors.white54 : Colors.black45);
    final bgColor = isDanger
        ? AppColors.danger.withAlpha(isDark ? 45 : 25)
        : (isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(6));
    final borderColor = isDanger
        ? AppColors.danger.withAlpha(60)
        : (isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(15));

    Widget button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        waitDuration: const Duration(milliseconds: 300),
        child: button,
      );
    }
    return button;
  }
}

class _DetailBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;

  const _DetailBadge({required this.label, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final c = color ?? (isDark ? Colors.white60 : AppColors.textSecondary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(8) : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? Colors.white.withAlpha(18) : AppColors.borderSubtle,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: c),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
