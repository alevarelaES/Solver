import 'package:flutter/material.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/shared/widgets/mini_sparkline.dart';
import 'package:solver/shared/widgets/premium_amount_text.dart';
import 'package:solver/shared/widgets/premium_card_base.dart';
import 'package:solver/shared/widgets/trend_badge.dart';

class DashboardKpiItem extends StatelessWidget {
  final String label;
  final double amount;
  final List<double> sparklineData;
  final double? percentChange;
  final Color color;
  final IconData icon;

  const DashboardKpiItem({
    super.key,
    required this.label,
    required this.amount,
    required this.sparklineData,
    required this.color,
    required this.icon,
    this.percentChange,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PremiumCardBase(
      variant: PremiumCardVariant.kpi,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              if (percentChange != null) TrendBadge(value: percentChange!),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 4),
          PremiumAmountText(
            amount: amount,
            currency: AppFormats.currencyCode,
            variant: PremiumAmountVariant.standard,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 30,
            width: double.infinity,
            child: MiniSparkline(
              data: sparklineData.isEmpty ? [0, 0] : sparklineData,
              color: color,
              strokeWidth: 2.0,
            ),
          ),
        ],
      ),
    );
  }
}
