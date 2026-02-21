part of 'schedule_view.dart';

// -------------------------------------------------------------------------------
// HERO HEADER
// -------------------------------------------------------------------------------
class _HeroHeader extends ConsumerWidget {
  final _ScopedUpcomingData data;
  const _HeroHeader({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCalendar = ref.watch(_calendarModeProvider);
    final scope = ref.watch(_invoiceScopeProvider);
    final calendarMonth = ref.watch(_calendarMonthProvider);
    final isDesktop = MediaQuery.sizeOf(context).width >= 980;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = isCalendar ? calendarMonth : DateTime.now();
    final monthLabel = DateFormat(
      'MMMM yyyy',
      'fr_FR',
    ).format(now).toUpperCase();
    final periodLabel = isCalendar
        ? monthLabel
        : scope == _InvoiceScope.month
        ? monthLabel
        : AppStrings.schedule.allPeriods;
    final showReferenceTotal =
        !isCalendar &&
        scope == _InvoiceScope.all &&
        (data.grandTotal - data.visibleGrandTotal).abs() > 0.009;

    // Compute overdue + upcoming-soon badge counts
    final today = DateTime(now.year, now.month, now.day);
    int overdueCount = 0;
    int upcomingSoonCount = 0;
    for (final t in data.manualList) {
      if (!t.isPending) continue;
      final due = DateTime(t.date.year, t.date.month, t.date.day);
      final diff = due.difference(today).inDays;
      if (due.isBefore(today)) {
        overdueCount++;
      } else if (diff <= 7) {
        upcomingSoonCount++;
      }
    }

    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${AppStrings.schedule.totalToPay} – $periodLabel',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.textDisabledDark : AppColors.textDisabled,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: AppFormats.formatFromChf(data.visibleGrandTotal),
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  letterSpacing: -1,
                ),
              ),
              if (showReferenceTotal)
                TextSpan(
                  text: ' (${AppFormats.formatFromChf(data.grandTotal)})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isCalendar
              ? AppStrings.schedule.calendarMonth
              : scope == _InvoiceScope.month
              ? AppStrings.schedule.monthInvoices
              : showReferenceTotal
              ? AppStrings.schedule.visibleWithTotal
              : AppStrings.schedule.allInvoices,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        if (overdueCount > 0 || upcomingSoonCount > 0) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (overdueCount > 0)
                _SummaryBadge(
                  count: overdueCount,
                  label: 'en retard',
                  color: AppColors.danger,
                  icon: Icons.schedule_rounded,
                ),
              if (upcomingSoonCount > 0)
                _SummaryBadge(
                  count: upcomingSoonCount,
                  label: 'à payer (7j)',
                  color: AppColors.warning,
                  icon: Icons.upcoming_outlined,
                ),
            ],
          ),
        ],
      ],
    );

    final controlsPanel = _ControlsPanel(
      isCalendar: isCalendar,
      scope: scope,
      showScope: !isCalendar,
      onModeChanged: (calendar) =>
          ref.read(_calendarModeProvider.notifier).state = calendar,
      onScopeChanged: (nextScope) =>
          ref.read(_invoiceScopeProvider.notifier).state = nextScope,
    );

    if (!isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          summary,
          const SizedBox(height: 16),
          Align(alignment: Alignment.centerRight, child: controlsPanel),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: summary),
        const SizedBox(width: 16),
        controlsPanel,
      ],
    );
  }
}

class _ControlsPanel extends StatelessWidget {
  final bool isCalendar;
  final _InvoiceScope scope;
  final bool showScope;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<_InvoiceScope> onScopeChanged;

  const _ControlsPanel({
    required this.isCalendar,
    required this.scope,
    required this.showScope,
    required this.onModeChanged,
    required this.onScopeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2A1A) : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderStrong,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowOverlaySm,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _FilterGroup(
            title: AppStrings.schedule.viewLabel,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ToggleChip(
                  label: AppStrings.schedule.viewList,
                  isActive: !isCalendar,
                  onTap: () => onModeChanged(false),
                ),
                _ToggleChip(
                  label: AppStrings.schedule.viewCalendar,
                  isActive: isCalendar,
                  onTap: () => onModeChanged(true),
                ),
              ],
            ),
          ),
          if (showScope)
            _FilterGroup(
              title: AppStrings.schedule.periodLabel,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ToggleChip(
                    label: AppStrings.schedule.periodMonth,
                    isActive: scope == _InvoiceScope.month,
                    onTap: () => onScopeChanged(_InvoiceScope.month),
                  ),
                  _ToggleChip(
                    label: AppStrings.schedule.periodAll,
                    isActive: scope == _InvoiceScope.all,
                    onTap: () => onScopeChanged(_InvoiceScope.all),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterGroup extends StatelessWidget {
  final String title;
  final Widget child;

  const _FilterGroup({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.s6,
        AppSpacing.sm,
        AppSpacing.s6,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceHeader,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _ToggleChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isActive ? AppColors.primary : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? const Color(0xFF2A3D20) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isActive
                ? AppColors.primary.withAlpha(60)
                : Colors.transparent,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------------------
// SUMMARY BADGE
// -------------------------------------------------------------------------------
class _SummaryBadge extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final IconData icon;

  const _SummaryBadge({
    required this.count,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.r20),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            '$count $label',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------------------
// BODY (switches list / calendar)
// -------------------------------------------------------------------------------
