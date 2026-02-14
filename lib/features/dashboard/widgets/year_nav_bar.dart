import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/dashboard/providers/dashboard_provider.dart';

class YearNavBar extends ConsumerWidget {
  const YearNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(selectedYearProvider);
    final currentYear = DateTime.now().year;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _NavButton(
            icon: Icons.chevron_left,
            onPressed: year > currentYear - 5
                ? () => ref.read(selectedYearProvider.notifier).state = year - 1
                : null,
            isDark: isDark,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$year',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          _NavButton(
            icon: Icons.chevron_right,
            onPressed: year < currentYear + 5
                ? () => ref.read(selectedYearProvider.notifier).state = year + 1
                : null,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isDark;

  const _NavButton({
    required this.icon,
    required this.onPressed,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 18),
        style: IconButton.styleFrom(
          backgroundColor: onPressed != null
              ? (isDark ? AppColors.borderDark : const Color(0xFFF3F4F6))
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
        onPressed: onPressed,
      ),
    );
  }
}
