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
    final now = isCalendar ? calendarMonth : DateTime.now();
    final monthLabel = DateFormat(
      'MMMM yyyy',
      'fr_FR',
    ).format(now).toUpperCase();
    final periodLabel = isCalendar
        ? monthLabel
        : scope == _InvoiceScope.month
        ? monthLabel
        : 'TOUTES PERIODES';
    final showReferenceTotal =
        !isCalendar &&
        scope == _InvoiceScope.all &&
        (data.grandTotal - data.visibleGrandTotal).abs() > 0.009;

    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TOTAL A PAYER - $periodLabel',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.textDisabled,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: AppFormats.currency.format(data.visibleGrandTotal),
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -1,
                ),
              ),
              if (showReferenceTotal)
                TextSpan(
                  text: ' (${AppFormats.currency.format(data.grandTotal)})',
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
        const SizedBox(height: 12),
        Text(
          isCalendar
              ? 'Calendrier du mois'
              : scope == _InvoiceScope.month
              ? 'Factures du mois'
              : showReferenceTotal
              ? 'Factures affichees (total complet entre parentheses)'
              : 'Toutes les factures',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.borderStrong),
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
            title: 'Vue',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ToggleChip(
                  label: 'Liste',
                  isActive: !isCalendar,
                  onTap: () => onModeChanged(false),
                ),
                _ToggleChip(
                  label: 'Calendrier',
                  isActive: isCalendar,
                  onTap: () => onModeChanged(true),
                ),
              ],
            ),
          ),
          if (showScope)
            _FilterGroup(
              title: 'Periode',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ToggleChip(
                    label: 'Mois',
                    isActive: scope == _InvoiceScope.month,
                    onTap: () => onScopeChanged(_InvoiceScope.month),
                  ),
                  _ToggleChip(
                    label: 'Toutes',
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
    final foreground = isActive ? AppColors.primary : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
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
// BODY (switches list / calendar)
// -------------------------------------------------------------------------------
