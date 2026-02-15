import 'package:flutter/material.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';

enum AppPanelVariant { surface, elevated, subtle }

class AppPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final AppPanelVariant variant;
  final Color? backgroundColor;
  final Color? borderColor;
  final List<BoxShadow>? boxShadow;
  final Border? border;
  final Clip clipBehavior;
  final VoidCallback? onTap;

  const AppPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.radius = AppRadius.lg,
    this.variant = AppPanelVariant.surface,
    this.backgroundColor,
    this.borderColor,
    this.boxShadow,
    this.border,
    this.clipBehavior = Clip.none,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = backgroundColor ?? _resolveBackground(isDark);
    final resolvedBorderColor =
        borderColor ?? (isDark ? AppColors.borderDark : AppColors.borderLight);
    final resolvedShadow = boxShadow ?? _resolveShadow(isDark);
    final decoration = BoxDecoration(
      color: bg,
      border: border ?? Border.all(color: resolvedBorderColor),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: resolvedShadow,
    );

    final panel = Container(
      margin: margin,
      padding: padding,
      clipBehavior: clipBehavior,
      decoration: decoration,
      child: child,
    );

    if (onTap == null) return panel;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: panel,
    );
  }

  Color _resolveBackground(bool isDark) {
    switch (variant) {
      case AppPanelVariant.surface:
        return isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
      case AppPanelVariant.elevated:
        return isDark ? AppColors.surfaceDark : AppColors.surfaceElevated;
      case AppPanelVariant.subtle:
        return isDark ? AppColors.backgroundDark : AppColors.surfaceHeader;
    }
  }

  List<BoxShadow>? _resolveShadow(bool isDark) {
    if (isDark) return null;
    switch (variant) {
      case AppPanelVariant.surface:
        return AppShadows.card;
      case AppPanelVariant.elevated:
        return AppShadows.cardHover;
      case AppPanelVariant.subtle:
        return null;
    }
  }
}
