import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/l10n/app_strings.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/budget/providers/goals_provider.dart';
import 'package:solver/shared/widgets/premium_card_base.dart';

/// Sidebar panel: top-priority active goals with a compact progress bar.
/// Shows up to [maxItems] goals, sorted by priority (lowest number = highest).
class BlocObjectifsPanel extends ConsumerWidget {
  final int maxItems;

  const BlocObjectifsPanel({super.key, this.maxItems = 4});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);

    return PremiumCardBase(
      variant: PremiumCardVariant.standard,
      padding: AppSpacing.paddingCardCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _SectionHeader(),
          const SizedBox(height: AppSpacing.sm),
          goalsAsync.when(
            loading: () => const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Text(
              AppStrings.goals.historyError(e),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.danger,
              ),
            ),
            data: (goals) {
              final active = goals
                  .where((g) => !g.isArchived && g.status != 'reached')
                  .toList()
                ..sort((a, b) => a.priority.compareTo(b.priority));

              if (active.isEmpty) {
                return _EmptyState();
              }

              final displayed = active.take(maxItems).toList();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < displayed.length; i++) ...[
                    if (i > 0)
                      const Divider(
                        height: AppSpacing.s14,
                        color: AppColors.borderSubtle,
                      ),
                    _GoalProgressRow(goal: displayed[i]),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      AppStrings.goals.panelHeaderTitle,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppColors.textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Text(
        AppStrings.goals.noGoalsList,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _GoalProgressRow extends StatelessWidget {
  final SavingGoal goal;

  const _GoalProgressRow({required this.goal});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final progress = (goal.progressPercent / 100).clamp(0.0, 1.0);

    // Color based on status
    final barColor = switch (goal.status) {
      'reached' => AppColors.primary,
      'on_track' => AppColors.primary,
      'late' => AppColors.warning,
      'urgent' => AppColors.danger,
      _ => AppColors.primary,
    };

    final xOverY = '${(goal.currentAmount / 1000).toStringAsFixed(0)}k '
        '/ ${(goal.targetAmount / 1000).toStringAsFixed(0)}k';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                goal.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              xOverY,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _CompactProgressBar(value: progress, color: barColor),
      ],
    );
  }
}

/// Slim linear progress bar — no external dependency required.
class _CompactProgressBar extends StatelessWidget {
  final double value; // 0.0 – 1.0
  final Color color;

  const _CompactProgressBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        return Stack(
          children: [
            Container(
              height: 4,
              width: totalWidth,
              decoration: BoxDecoration(
                color: color.withAlpha(35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              height: 4,
              width: totalWidth * value,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        );
      },
    );
  }
}
