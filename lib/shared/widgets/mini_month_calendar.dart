import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/shared/widgets/premium_card_base.dart';

/// Compact month calendar grid (7×6).
/// Marks days with upcoming (green dot) or overdue (red dot) events.
class MiniMonthCalendar extends StatefulWidget {
  /// First day of the displayed month.
  final DateTime initialMonth;

  /// Dates that have a scheduled (upcoming) event → green dot.
  final List<DateTime> scheduledDates;

  /// Dates that have an overdue event → red dot.
  final List<DateTime> overdueDates;

  /// Called when the user taps a day cell.
  final ValueChanged<DateTime>? onDayTapped;

  const MiniMonthCalendar({
    super.key,
    required this.initialMonth,
    required this.scheduledDates,
    required this.overdueDates,
    this.onDayTapped,
  });

  @override
  State<MiniMonthCalendar> createState() => _MiniMonthCalendarState();
}

class _MiniMonthCalendarState extends State<MiniMonthCalendar> {
  late DateTime _month;
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.initialMonth.year, widget.initialMonth.month);
  }

  void _prevMonth() =>
      setState(() => _month = DateTime(_month.year, _month.month - 1));

  void _nextMonth() =>
      setState(() => _month = DateTime(_month.year, _month.month + 1));

  bool _hasOverdue(DateTime day) => widget.overdueDates.any(
        (d) => d.year == day.year && d.month == day.month && d.day == day.day,
      );

  bool _hasScheduled(DateTime day) => widget.scheduledDates.any(
        (d) => d.year == day.year && d.month == day.month && d.day == day.day,
      );

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }

  bool _isSelected(DateTime day) =>
      _selected != null &&
      _selected!.year == day.year &&
      _selected!.month == day.month &&
      _selected!.day == day.day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    // Build day list: Monday-first grid
    final firstDay = DateTime(_month.year, _month.month, 1);
    // weekday: 1=Mon … 7=Sun → offset so Mon=0
    final startOffset = (firstDay.weekday - 1) % 7;
    final daysInMonth =
        DateTime(_month.year, _month.month + 1, 0).day;

    return PremiumCardBase(
      variant: PremiumCardVariant.standard,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Month navigation ──────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: _prevMonth,
                child: const Icon(
                  Icons.chevron_left_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                DateFormat('MMMM yyyy', 'fr_FR').format(_month).toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.6,
                ),
              ),
              GestureDetector(
                onTap: _nextMonth,
                child: const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // ── Weekday headers ───────────────────────────────────────────────
          Row(
            children: ['L', 'M', 'M', 'J', 'V', 'S', 'D']
                .map(
                  (label) => Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDisabled,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppSpacing.xs),
          // ── Calendar grid ─────────────────────────────────────────────────
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.0,
            ),
            itemCount: 42, // 6 rows × 7 cols
            itemBuilder: (context, index) {
              final dayNumber = index - startOffset + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }
              final day = DateTime(_month.year, _month.month, dayNumber);
              final overdue = _hasOverdue(day);
              final scheduled = _hasScheduled(day);
              final today = _isToday(day);
              final selected = _isSelected(day);

              return GestureDetector(
                onTap: () {
                  setState(() => _selected = day);
                  widget.onDayTapped?.call(day);
                },
                child: _DayCell(
                  day: dayNumber,
                  isToday: today,
                  isSelected: selected,
                  hasOverdue: overdue,
                  hasScheduled: scheduled,
                  textPrimary: textPrimary,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final bool isToday;
  final bool isSelected;
  final bool hasOverdue;
  final bool hasScheduled;
  final Color textPrimary;

  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.hasOverdue,
    required this.hasScheduled,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = hasOverdue
        ? AppColors.danger
        : hasScheduled
            ? AppColors.primary
            : null;

    Color? bgColor;
    Color textColor = textPrimary;
    if (isSelected) {
      bgColor = AppColors.primary.withAlpha(30);
      textColor = AppColors.primary;
    } else if (isToday) {
      bgColor = AppColors.primary.withAlpha(18);
      textColor = AppColors.primary;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: bgColor != null
              ? BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                )
              : null,
          child: Center(
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isToday || isSelected
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ),
        if (dotColor != null) ...[
          const SizedBox(height: 1),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }
}
