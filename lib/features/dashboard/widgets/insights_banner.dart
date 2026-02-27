import 'package:flutter/material.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/dashboard/models/dashboard_data.dart';

class InsightsBanner extends StatelessWidget {
  final DashboardData data;

  const InsightsBanner({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final insights = _buildInsights(data);

    if (insights.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: insights.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) => _InsightChip(
          insight: insights[i],
          isDark: isDark,
        ),
      ),
    );
  }

  List<_Insight> _buildInsights(DashboardData data) {
    final insights = <_Insight>[];
    final now = DateTime.now();
    final currentMonth = now.month;
    final prevMonth = currentMonth == 1 ? 12 : currentMonth - 1;

    final currentExpenses = data.currentMonthExpenses;
    final prevExpenses = data.expensesForMonth(prevMonth);
    final currentIncome = data.currentMonthIncome;

    // Expense trend
    if (prevExpenses > 0 && currentExpenses > 0) {
      final pct = ((currentExpenses - prevExpenses) / prevExpenses) * 100;
      final isUp = pct > 0;
      insights.add(_Insight(
        icon: isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
        label: 'Dépenses ${isUp ? '+' : ''}${pct.toStringAsFixed(0)}% vs mois dernier',
        color: isUp ? AppColors.danger : AppColors.success,
      ));
    }

    // Savings rate
    if (currentIncome > 0) {
      final saved = currentIncome - currentExpenses;
      final rate = (saved / currentIncome * 100).clamp(-99.0, 99.0);
      final isPositive = rate >= 0;
      insights.add(_Insight(
        icon: Icons.savings_outlined,
        label: 'Épargne du mois : ${rate.toStringAsFixed(0)}%',
        color: isPositive ? AppColors.primary : AppColors.warning,
      ));
    }

    // Balance health
    if (currentIncome > 0) {
      final ratio = currentExpenses / currentIncome;
      if (ratio > 0.9) {
        insights.add(const _Insight(
          icon: Icons.info_outline_rounded,
          label: 'Budget presque atteint ce mois',
          color: AppColors.warning,
        ));
      } else if (ratio < 0.5 && currentExpenses > 0) {
        insights.add(const _Insight(
          icon: Icons.check_circle_outline_rounded,
          label: 'Bonne maîtrise des dépenses',
          color: AppColors.success,
        ));
      }
    }

    return insights;
  }
}

class _Insight {
  final IconData icon;
  final String label;
  final Color color;

  const _Insight({
    required this.icon,
    required this.label,
    required this.color,
  });
}

class _InsightChip extends StatelessWidget {
  final _Insight insight;
  final bool isDark;

  const _InsightChip({required this.insight, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: insight.color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(AppRadius.r20),
        border: Border.all(
          color: insight.color.withValues(alpha: isDark ? 0.2 : 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(insight.icon, size: 13, color: insight.color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            insight.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? insight.color.withValues(alpha: 0.9)
                  : insight.color,
            ),
          ),
        ],
      ),
    );
  }
}
