import 'package:flutter/material.dart';
import 'package:solver/core/theme/app_premium_theme.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/shared/widgets/chart_tab_switcher.dart';

enum ScheduleViewType { list, calendar }
enum SchedulePeriodScope { month, all }

class ScheduleHeaderControls extends StatelessWidget {
  final ScheduleViewType viewType;
  final ValueChanged<ScheduleViewType> onViewChanged;
  final SchedulePeriodScope periodScope;
  final ValueChanged<SchedulePeriodScope> onPeriodChanged;

  const ScheduleHeaderControls({
    super.key,
    required this.viewType,
    required this.onViewChanged,
    required this.periodScope,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Vue Control
        _ControlGroup(
          label: 'Vue',
          child: ChartTabSwitcher(
            tabs: const ['Liste', 'Calendrier'],
            selectedIndex: viewType == ScheduleViewType.list ? 0 : 1,
            onChanged: (idx) {
              onViewChanged(idx == 0 ? ScheduleViewType.list : ScheduleViewType.calendar);
            },
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        // Période Control
        _ControlGroup(
          label: 'Période',
          child: ChartTabSwitcher(
            tabs: const ['Mois', 'Toutes'],
            selectedIndex: periodScope == SchedulePeriodScope.month ? 0 : 1,
            onChanged: (idx) {
              onPeriodChanged(idx == 0 ? SchedulePeriodScope.month : SchedulePeriodScope.all);
            },
          ),
        ),
      ],
    );
  }
}

class _ControlGroup extends StatelessWidget {
  final String label;
  final Widget child;

  const _ControlGroup({
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.extension<PremiumThemeExtension>()!;
    
    return Container(
      padding: const EdgeInsets.only(top: 4, left: 6, right: 6, bottom: 6),
      decoration: BoxDecoration(
        color: p.glassSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg + 2),
        border: Border.all(color: p.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 4),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
