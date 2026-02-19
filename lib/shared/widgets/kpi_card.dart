import 'package:flutter/material.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_text_styles.dart';
import 'package:solver/shared/widgets/glass_container.dart';

class KpiCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  final bool isCurrency;
  final String? suffix;

  const KpiCard({
    super.key,
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    this.isCurrency = true,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final formatted = isCurrency
        ? AppFormats.currency.format(amount)
        : '${amount.toStringAsFixed(1)}${suffix ?? ''}';

    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.r10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(formatted, style: AppTextStyles.amount(color)),
        ],
      ),
    );
  }
}


