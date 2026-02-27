import 'package:flutter/material.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/shared/widgets/premium_card_base.dart';

/// Pill badge signaling overdue invoices.
/// Color: AppColors.danger, chip variant of PremiumCardBase.
class OverdueBadge extends StatelessWidget {
  final int count;

  /// Suffix label shown after the count (uppercased).
  final String suffix;

  const OverdueBadge({
    super.key,
    required this.count,
    this.suffix = 'RETARD',
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCardBase(
      variant: PremiumCardVariant.chip,
      overrideSurface: AppColors.danger.withAlpha(22),
      overrideBorder: AppColors.danger.withAlpha(90),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_rounded, size: 12, color: AppColors.danger),
          const SizedBox(width: 4),
          Text(
            '$count $suffix',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.danger,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
