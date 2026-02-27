import 'package:flutter/material.dart';
import 'package:solver/core/theme/app_premium_theme.dart';

class PremiumDivider extends StatelessWidget {
  final Axis direction;
  final double thickness;
  final double? indent;
  final double? endIndent;

  const PremiumDivider({
    super.key,
    this.direction = Axis.horizontal,
    this.thickness = 1.0,
    this.indent,
    this.endIndent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.extension<PremiumThemeExtension>()!;

    if (direction == Axis.vertical) {
      return VerticalDivider(
        color: p.glassBorder,
        thickness: thickness,
        indent: indent,
        endIndent: endIndent,
        width: thickness,
      );
    }

    return Divider(
      color: p.glassBorder,
      thickness: thickness,
      indent: indent,
      endIndent: endIndent,
      height: thickness,
    );
  }
}
