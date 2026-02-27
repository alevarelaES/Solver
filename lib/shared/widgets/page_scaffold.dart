import 'package:flutter/material.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/core/theme/app_premium_theme.dart';

class AppPageScaffold extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool scrollable;

  const AppPageScaffold({
    super.key,
    required this.child,
    this.maxWidth = double.infinity,
    this.padding,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final p = theme.extension<PremiumThemeExtension>()!;
    
    final width = MediaQuery.sizeOf(context).width;
    final resolvedPadding =
        padding ??
        (width < AppBreakpoints.tablet
            ? const EdgeInsets.all(AppSpacing.md)
            : AppSpacing.paddingPage);

    final mainPadding = Padding(
      padding: resolvedPadding,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );

    final scrollableContent = scrollable
        ? SingleChildScrollView(child: mainPadding)
        : mainPadding;

    return Container(
      color: isDark ? p.canvasDeep : theme.scaffoldBackgroundColor,
      child: Stack(
        children: [
          // Blob 1: Top Left (Primary/Green)
          Positioned(
            top: -200,
            left: -100,
            child: Container(
              width: 800,
              height: 800,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.15),
                    AppColors.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Blob 2: Bottom Right (Warning/Amber)
          Positioned(
            bottom: -200,
            right: -200,
            child: Container(
              width: 1000,
              height: 1000,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.warning.withValues(alpha: isDark ? 0.20 : 0.10),
                    AppColors.warning.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Blob 3: Center (Primary Dark offset)
          Positioned(
            top: MediaQuery.of(context).size.height * 0.3,
            right: MediaQuery.of(context).size.width * 0.2,
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryDark.withValues(alpha: isDark ? 0.20 : 0.10),
                    AppColors.primaryDark.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Foreground content
          Positioned.fill(child: scrollableContent),
        ],
      ),
    );
  }
}
