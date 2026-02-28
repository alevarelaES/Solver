import 'package:flutter/material.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';

enum SchedulePeriodScope { month, all }

/// Period selector with the same pill/segmented design as _ViewTabSwitcher.
class ScheduleHeaderControls extends StatelessWidget {
  final SchedulePeriodScope periodScope;
  final ValueChanged<SchedulePeriodScope> onPeriodChanged;

  const ScheduleHeaderControls({
    super.key,
    required this.periodScope,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final current = periodScope == SchedulePeriodScope.month ? 0 : 1;

    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withAlpha(13)
            : Colors.black.withAlpha(8),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha(20)
              : Colors.black.withAlpha(15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PeriodTab(
            label: 'Mois',
            index: 0,
            current: current,
            isDark: isDark,
            onTap: () => onPeriodChanged(SchedulePeriodScope.month),
          ),
          const SizedBox(width: 2),
          _PeriodTab(
            label: 'Toutes',
            index: 1,
            current: current,
            isDark: isDark,
            onTap: () => onPeriodChanged(SchedulePeriodScope.all),
          ),
        ],
      ),
    );
  }
}

class _PeriodTab extends StatelessWidget {
  final String label;
  final int index;
  final int current;
  final bool isDark;
  final VoidCallback onTap;

  const _PeriodTab({
    required this.label,
    required this.index,
    required this.current,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = index == current;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
          ),
        ),
      ),
    );
  }
}
