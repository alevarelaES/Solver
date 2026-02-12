import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:solver/core/theme/app_theme.dart';

class GlassContainer extends StatefulWidget {
  final Widget child;
  final double blur;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 10,
    this.borderColor,
    this.padding = const EdgeInsets.all(24),
    this.borderRadius = 24,
  });

  @override
  State<GlassContainer> createState() => _GlassContainerState();
}

class _GlassContainerState extends State<GlassContainer> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: widget.blur,
              sigmaY: widget.blur,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: widget.padding,
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: Border.all(
                  color: _hovered
                      ? AppColors.electricBlue.withAlpha(80)
                      : (widget.borderColor ?? AppColors.borderSubtle),
                  width: 1,
                ),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
