import 'package:flutter/material.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/theme/app_text_styles.dart';
import 'package:solver/core/theme/app_theme.dart';
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
    final formatted = isCurrency
        ? AppFormats.currency.format(amount)
        : '${amount.toStringAsFixed(1)}${suffix ?? ''}';

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
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
