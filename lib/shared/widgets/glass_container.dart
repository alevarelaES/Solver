import 'package:flutter/material.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/shared/widgets/app_panel.dart';

/// Clean card container replacing the old glassmorphic GlassContainer.
/// Keeps the same class name + constructor signature so existing code compiles.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur; // ignored — kept for API compat
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 10,
    this.borderColor,
    this.padding = AppSpacing.paddingPage,
    this.borderRadius = AppRadius.lg,
  });

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: padding,
      radius: borderRadius,
      borderColor: borderColor ??
          (Theme.of(context).brightness == Brightness.dark
              ? AppColors.borderDark
              : AppColors.borderLight),
      variant: AppPanelVariant.surface,
      child: child,
    );
  }
}
