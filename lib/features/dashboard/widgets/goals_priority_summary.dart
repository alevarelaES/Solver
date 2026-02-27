import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/core/settings/currency_settings_provider.dart';
import 'package:solver/features/budget/providers/goals_provider.dart';
import 'package:solver/shared/widgets/premium_card_base.dart';

class GoalsPrioritySummaryCard extends ConsumerWidget {
  const GoalsPrioritySummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appCurrencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goalsAsync = ref.watch(goalsProvider);

    return PremiumCardBase(
      variant: PremiumCardVariant.standard,
      padding: AppSpacing.paddingCardCompact,
      child: goalsAsync.when(
        loading: () => const SizedBox(
          height: 180,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, _) => SizedBox(
          height: 120,
          child: Center(
            child: Text(
              'Objectifs indisponibles',
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
        ),
        data: (goals) {
          final active = goals.where((g) => !g.isArchived).toList();
          final pending = active
              .where((g) => g.remainingAmount > 0.01)
              .toList();

          pending.sort((a, b) {
            final cmpDays = _daysUntil(
              a.targetDate,
            ).compareTo(_daysUntil(b.targetDate));
            if (cmpDays != 0) return cmpDays;
            final cmpPriority = a.priority.compareTo(b.priority);
            if (cmpPriority != 0) return cmpPriority;
            return b.progressPercent.compareTo(a.progressPercent);
          });

          final display = pending.take(4).toList();
          final avgProgress = active.isEmpty
              ? 0.0
              : active
                        .map((g) => g.progressPercent.clamp(0, 100))
                        .reduce((a, b) => a + b) /
                    active.length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Objectifs prioritaires',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Text(
                      '${pending.length} actifs',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Progression moyenne ${avgProgress.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (display.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text(
                    'Aucun objectif prioritaire en cours',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                )
              else
                ...display.map(
                  (goal) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: GestureDetector(
                      onTap: () => context.go('/goals'),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: _GoalLine(goal: goal),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _GoalLine extends StatefulWidget {
  final SavingGoal goal;

  const _GoalLine({required this.goal});

  @override
  State<_GoalLine> createState() => _GoalLineState();
}

class _GoalLineState extends State<_GoalLine> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pct = widget.goal.progressPercent.clamp(0, 100).toDouble();
    final progress = (pct / 100).clamp(0.0, 1.0);
    final days = _daysUntil(widget.goal.targetDate);

    final accent = days <= 7
        ? AppColors.danger
        : days <= 30
        ? AppColors.warning
        : AppColors.primary;

    final subtitle = days < 0
        ? 'Retard ${days.abs()}j'
        : days == 0
        ? 'Echeance aujourd\'hui'
        : 'J-$days';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
          color: _isHovered 
              ? accent.withValues(alpha: isDark ? 0.20 : 0.15)
              : accent.withValues(alpha: isDark ? 0.12 : 0.07),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.goal.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
              Text(
                AppFormats.formatFromChfCompact(widget.goal.remainingAmount),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${AppFormats.formatFromChfCompact(widget.goal.currentAmount)} / ${AppFormats.formatFromChfCompact(widget.goal.targetAmount)}',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              const Spacer(),
              Text(
                '${pct.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: isDark
                  ? AppColors.surfaceDark.withValues(alpha: 0.5)
                  : AppColors.surfaceElevated,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          ],
        ),
      ),
    );
  }
}

int _daysUntil(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  return target.difference(today).inDays;
}
