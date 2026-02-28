import 'package:flutter/material.dart';
import 'package:solver/core/l10n/app_strings.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';

/// Empty state for an invoice section: icon + message.
/// Transparent background, clean design.
class ScheduleEmptyState extends StatelessWidget {
  final String? message;
  final String? subtitle;
  final IconData icon;
  final Color? accentColor;

  const ScheduleEmptyState({
    super.key,
    this.message,
    this.subtitle,
    this.icon = Icons.check_circle_outline_rounded,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xxl,
        horizontal: AppSpacing.md,
      ),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: color.withAlpha(100)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message ?? AppStrings.schedule.noDeadlines,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle ?? AppStrings.schedule.allGood,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textDisabled,
            ),
          ),
        ],
      ),
      ),
    );
  }
}

