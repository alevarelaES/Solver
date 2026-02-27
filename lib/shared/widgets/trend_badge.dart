import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solver/core/theme/app_theme.dart';

class TrendBadge extends StatelessWidget {
  final double value; // Typically a percentage, e.g., 5.2 for 5.2%
  final String suffix;

  const TrendBadge({
    super.key,
    required this.value,
    this.suffix = '%',
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = value >= 0;
    final color = isPositive ? AppColors.success : AppColors.danger;
    final icon = isPositive ? Icons.trending_up : Icons.trending_down;
    
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            '${value.abs().toStringAsFixed(1)}$suffix',
            style: GoogleFonts.robotoMono( // Using monospace for numbers usually looks better
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
