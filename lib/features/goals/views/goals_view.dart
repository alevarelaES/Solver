import 'package:flutter/material.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/settings/currency_settings_provider.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/l10n/app_strings.dart';
import 'package:solver/features/budget/providers/budget_provider.dart';
import 'package:solver/features/budget/providers/goals_provider.dart';
import 'package:solver/shared/widgets/app_panel.dart';
import 'package:solver/shared/widgets/page_header.dart';
import 'package:solver/shared/widgets/page_scaffold.dart';
import 'package:solver/shared/widgets/goal_progress_donut.dart';
import 'package:solver/features/goals/widgets/goals_dashboard.dart';
import 'package:solver/features/goals/widgets/goals_tab_bar.dart';

part 'goals_view.logic.part.dart';
part 'goals_view.widgets.part.dart';

double _parseNumber(String raw) =>
    double.tryParse(raw.replaceAll(' ', '').replaceAll(',', '.')) ?? 0.0;

String _editableInputValue(double value, {int maxDecimals = 0}) {
  if (value.abs() < 0.000001) return '';
  final text = value.toStringAsFixed(maxDecimals);
  // Only strip trailing zeros after a decimal point — never from integers.
  if (!text.contains('.')) return text;
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}

bool _isDebtType(String value) => value.toLowerCase() == 'debt';

bool _isAchievedStatus(String status) => status.toLowerCase() == 'achieved';

String _formatDateShort(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d.$m.${date.year}';
}

int _daysUntil(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  return target.difference(today).inDays;
}

enum _GoalAlertLevel { normal, attention, critical, overdue, achieved }

class _GoalAlertAssessment {
  final _GoalAlertLevel level;
  final String label;
  final Color color;
  final IconData icon;

  const _GoalAlertAssessment({
    required this.level,
    required this.label,
    required this.color,
    required this.icon,
  });

  bool get isPriority =>
      level == _GoalAlertLevel.critical || level == _GoalAlertLevel.overdue;

  bool get isAttention => level == _GoalAlertLevel.attention;
}

int _projectedDelayMonths(SavingGoal goal) {
  if (goal.projectedDate == null) {
    return goal.remainingAmount > 0 ? 999 : 0;
  }
  final delay = _monthIndex(goal.projectedDate!) - _monthIndex(goal.targetDate);
  return delay > 0 ? delay : 0;
}

_GoalAlertAssessment _assessGoalAlert(SavingGoal goal) {
  if (_isAchievedStatus(goal.status) || goal.remainingAmount <= 0.01) {
    return _GoalAlertAssessment(
      level: _GoalAlertLevel.achieved,
      label: AppStrings.goals.statusReached,
      color: AppColors.primary,
      icon: Icons.check_circle_rounded,
    );
  }

  final days = _daysUntil(goal.targetDate);
  if (days < 0) {
    return _GoalAlertAssessment(
      level: _GoalAlertLevel.overdue,
      label: AppStrings.goals.alertOverdueDeadline,
      color: AppColors.danger,
      icon: Icons.error_rounded,
    );
  }

  final requiredMonthly = goal.recommendedMonthly <= 0
      ? 0.0
      : goal.recommendedMonthly;
  final hasPlan = goal.monthlyContribution > 0.01;
  final coverage = requiredMonthly <= 0
      ? 1.0
      : goal.monthlyContribution / requiredMonthly;
  final delayMonths = _projectedDelayMonths(goal);

  if (days <= 15) {
    if (!hasPlan || coverage < 0.80 || delayMonths >= 1) {
      return _GoalAlertAssessment(
        level: _GoalAlertLevel.critical,
        label: AppStrings.goals.alertUrgentSoon,
        color: AppColors.danger,
        icon: Icons.priority_high_rounded,
      );
    }
    return _GoalAlertAssessment(
      level: _GoalAlertLevel.attention,
      label: AppStrings.goals.alertAttentionSoon,
      color: AppColors.warning,
      icon: Icons.warning_amber_rounded,
    );
  }

  if (days <= 30) {
    if (!hasPlan || coverage < 0.55 || delayMonths >= 2) {
      return _GoalAlertAssessment(
        level: _GoalAlertLevel.critical,
        label: AppStrings.goals.alertUrgentAdjustment,
        color: AppColors.danger,
        icon: Icons.priority_high_rounded,
      );
    }
    if (coverage < 0.95 || delayMonths >= 1) {
      return _GoalAlertAssessment(
        level: _GoalAlertLevel.attention,
        label: AppStrings.goals.alertAttentionAdjust,
        color: AppColors.warning,
        icon: Icons.warning_amber_rounded,
      );
    }
  }

  if (days <= 60) {
    if (!hasPlan || coverage < 0.75 || delayMonths >= 2) {
      return _GoalAlertAssessment(
        level: _GoalAlertLevel.attention,
        label: AppStrings.goals.alertAttentionApproach,
        color: AppColors.warning,
        icon: Icons.warning_amber_rounded,
      );
    }
  }

  if (days <= 90 && coverage < 0.65 && delayMonths >= 1) {
    return _GoalAlertAssessment(
      level: _GoalAlertLevel.attention,
      label: AppStrings.goals.alertAttentionLowRhythm,
      color: AppColors.warning,
      icon: Icons.warning_amber_rounded,
    );
  }

  if (!hasPlan && goal.remainingAmount > 0) {
    return _GoalAlertAssessment(
      level: _GoalAlertLevel.normal,
      label: AppStrings.goals.alertToPlan,
      color: AppColors.textSecondary,
      icon: Icons.schedule_rounded,
    );
  }

  if (coverage < 0.95 || delayMonths >= 1) {
    return _GoalAlertAssessment(
      level: _GoalAlertLevel.normal,
      label: AppStrings.goals.alertToAdjust,
      color: AppColors.textSecondary,
      icon: Icons.tune_rounded,
    );
  }

  return _GoalAlertAssessment(
    level: _GoalAlertLevel.normal,
    label: AppStrings.goals.alertOnTrack,
    color: AppColors.successStrong,
    icon: Icons.track_changes_rounded,
  );
}

String _deadlineLabel(SavingGoal goal) {
  final days = _daysUntil(goal.targetDate);
  if (_isAchievedStatus(goal.status)) {
    return AppStrings.goals.achievedDeadline(_formatDateShort(goal.targetDate));
  }
  if (days < 0) return AppStrings.goals.overdueByDays(days.abs());
  if (days == 0) return AppStrings.goals.deadlineToday;
  if (days == 1) return AppStrings.goals.deadlineTomorrow;
  return AppStrings.goals.deadlineInDays(days);
}

int _monthsRemaining(DateTime from, DateTime target) {
  final monthDelta =
      (target.year - from.year) * 12 + (target.month - from.month) + 1;
  return monthDelta < 0 ? 0 : monthDelta;
}

DateTime? _projectedDate(double remaining, double monthlyAmount) {
  if (remaining <= 0) return DateTime.now();
  if (monthlyAmount <= 0) return null;
  final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
  final monthsToGoal = (remaining / monthlyAmount).ceil();
  return DateTime(monthStart.year, monthStart.month + monthsToGoal - 1, 1);
}

int _monthIndex(DateTime d) => d.year * 12 + d.month;


class GoalsView extends ConsumerStatefulWidget {
  const GoalsView({super.key});

  @override
  ConsumerState<GoalsView> createState() => _GoalsViewState();
}

class _GoalsViewState extends ConsumerState<GoalsView> {
  String _activeType = 'savings';
  void _withState(VoidCallback cb) => setState(cb);

  @override
  Widget build(BuildContext context) {
    ref.watch(appCurrencyProvider);
    return _buildGoalsView(context);
  }
}
