import 'package:flutter/material.dart';

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
    this.padding = const EdgeInsets.all(24),
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? (isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB)),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: child,
    );
  }
}
