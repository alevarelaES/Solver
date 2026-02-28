import 'package:flutter/material.dart';
import 'package:solver/core/theme/app_premium_theme.dart';
import 'dart:ui';

enum PremiumCardVariant { hero, standard, kpi, listItem, chip, sidebar }

class PremiumCardBase extends StatefulWidget {
  final Widget child;
  final PremiumCardVariant variant;

  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final double? borderRadius;

  final Color? overrideSurface;
  final Color? overrideBorder;
  final Gradient? overrideGradient;

  final bool showGlow;
  final Color? glowColor;

  final bool enableBlur;
  final VoidCallback? onTap;
  final bool selected;

  const PremiumCardBase({
    super.key,
    required this.child,
    this.variant = PremiumCardVariant.standard,
    this.padding,
    this.width,
    this.height,
    this.borderRadius,
    this.overrideSurface,
    this.overrideBorder,
    this.overrideGradient,
    this.showGlow = false,
    this.glowColor,
    this.enableBlur = true,
    this.onTap,
    this.selected = false,
  });

  @override
  State<PremiumCardBase> createState() => _PremiumCardBaseState();
}

class _PremiumCardBaseState extends State<PremiumCardBase> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.extension<PremiumThemeExtension>()!;

    double resolvedRadius = widget.borderRadius ?? 0.0;
    EdgeInsetsGeometry resolvedPadding = widget.padding ?? EdgeInsets.zero;
    Color resolvedSurface = Colors.transparent;
    Border? resolvedBorder;
    Gradient? resolvedGradient;

    switch (widget.variant) {
      case PremiumCardVariant.hero:
        resolvedRadius = 20.0;
        resolvedPadding = const EdgeInsets.all(24.0);
        resolvedSurface = p.glassSurfaceHero;
        resolvedGradient = p.heroCardGradient;
        resolvedBorder = Border.all(color: p.glassBorderActive);
        break;
      case PremiumCardVariant.standard:
        resolvedRadius = 16.0;
        resolvedPadding = const EdgeInsets.all(16.0);
        resolvedSurface = p.glassSurface;
        resolvedBorder = Border.all(color: widget.selected ? p.glassBorderActive : p.glassBorder);
        break;
      case PremiumCardVariant.kpi:
        resolvedRadius = 12.0;
        resolvedPadding = const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0);
        resolvedSurface = p.glassSurface;
        resolvedBorder = Border.all(color: widget.selected ? p.glassBorderActive : p.glassBorder);
        break;
      case PremiumCardVariant.listItem:
        resolvedRadius = 0.0;
        resolvedPadding = const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0);
        resolvedSurface = Colors.transparent;
        // No border, uses PremiumDivider
        break;
      case PremiumCardVariant.chip:
        resolvedRadius = 99.0;
        resolvedPadding = const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0);
        resolvedSurface = p.glassSurface; // Or a lighter variant if needed
        resolvedBorder = Border.all(color: p.glassBorder);
        break;
      case PremiumCardVariant.sidebar:
        resolvedRadius = 10.0;
        resolvedPadding = const EdgeInsets.all(12.0);
        resolvedSurface = Colors.transparent;
        break;
    }

    if (widget.overrideSurface != null) resolvedSurface = widget.overrideSurface!;
    if (widget.overrideGradient != null) resolvedGradient = widget.overrideGradient!;
    if (widget.overrideBorder != null) {
      resolvedBorder = Border.all(color: widget.overrideBorder!);
    }
    if (widget.borderRadius != null) resolvedRadius = widget.borderRadius!;

    Widget innerContent = widget.onTap != null
        ? Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(resolvedRadius),
              overlayColor: WidgetStatePropertyAll(p.glassOverlay),
              child: Padding(
                padding: resolvedPadding,
                child: widget.child,
              ),
            ),
          )
        : Padding(
            padding: resolvedPadding,
            child: widget.child,
          );

    Widget finalContent = innerContent;

    if (widget.enableBlur && p.blurEnabled) {
      Color finalSurface = resolvedSurface;
      if (widget.onTap != null && _isHovered) {
        if (theme.brightness == Brightness.dark) {
          finalSurface = Colors.white.withValues(alpha: 0.12);
        } else {
          finalSurface = Colors.white.withValues(alpha: 0.85); 
        }
      }

      finalContent = Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(resolvedRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: p.blurSigma, sigmaY: p.blurSigma),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: resolvedGradient == null ? finalSurface : null,
                    gradient: resolvedGradient,
                  ),
                ),
              ),
            ),
          ),
          innerContent,
        ],
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: (widget.enableBlur && p.blurEnabled) ? null : (resolvedGradient == null ? resolvedSurface : null),
          gradient: (widget.enableBlur && p.blurEnabled) ? null : resolvedGradient,
          borderRadius: BorderRadius.circular(resolvedRadius),
          border: resolvedBorder,
          boxShadow: widget.showGlow ? _buildGlow(p) : null,
        ),
        child: finalContent,
      ),
    );
  }

  List<BoxShadow> _buildGlow(PremiumThemeExtension p) {
    if (widget.glowColor != null) {
      return [
        BoxShadow(
          color: widget.glowColor!.withValues(alpha: p.glowDangerOpacity),
          blurRadius: p.glowDangerRadius,
          spreadRadius: 2,
        )
      ];
    }
    return [
      BoxShadow(
        color: const Color(0xFF689E28).withValues(alpha: p.glowGreenOpacity),
        blurRadius: p.glowGreenBlur,
        spreadRadius: p.glowGreenRadius,
      )
    ];
  }
}
