import 'package:flutter/material.dart';
import 'package:solver/core/theme/app_tokens.dart';

class AppPageScaffold extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool scrollable;

  const AppPageScaffold({
    super.key,
    required this.child,
    this.maxWidth = 1380,
    this.padding,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final resolvedPadding =
        padding ??
        (width < AppBreakpoints.tablet
            ? const EdgeInsets.all(AppSpacing.md)
            : AppSpacing.paddingPage);

    final content = Padding(
      padding: resolvedPadding,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );

    if (scrollable) {
      return SingleChildScrollView(child: content);
    }

    return content;
  }
}
