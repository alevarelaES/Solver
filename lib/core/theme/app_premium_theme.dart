import 'dart:ui';
import 'package:flutter/material.dart';

class PremiumThemeExtension extends ThemeExtension<PremiumThemeExtension> {
  // --- Surfaces ---
  final Color canvasDeep;
  final Color canvasMid;
  final Color glassSurface;
  final Color glassSurfaceHero;
  final Color glassBorder;
  final Color glassBorderActive;
  final Color glassBorderAccent;
  final Color glassOverlay;

  // --- Glow ---
  final double glowGreenOpacity;
  final double glowGreenRadius;
  final double glowGreenBlur;
  final double glowDangerOpacity;
  final double glowDangerRadius;

  // --- Blur ---
  final double blurSigma;
  final bool blurEnabled;

  // --- Gradients ---
  final Gradient heroCardGradient;
  final Gradient accentLineGradient;
  final Gradient dangerLineGradient;
  final Gradient warmthGradient;

  // --- Typography ---
  final double heroAmountSize;
  final FontWeight heroAmountWeight;
  final double kpiAmountSize;
  final FontWeight kpiAmountWeight;
  final double tableAmountSize;
  final List<FontFeature> fontFeatureTabular;

  // --- Skeletons ---
  final Color skeletonBase;
  final Color skeletonShimmer;
  final Duration skeletonDuration;
  final double skeletonRadius;

  const PremiumThemeExtension({
    required this.canvasDeep,
    required this.canvasMid,
    required this.glassSurface,
    required this.glassSurfaceHero,
    required this.glassBorder,
    required this.glassBorderActive,
    required this.glassBorderAccent,
    required this.glassOverlay,
    required this.glowGreenOpacity,
    required this.glowGreenRadius,
    required this.glowGreenBlur,
    required this.glowDangerOpacity,
    required this.glowDangerRadius,
    required this.blurSigma,
    required this.blurEnabled,
    required this.heroCardGradient,
    required this.accentLineGradient,
    required this.dangerLineGradient,
    required this.warmthGradient,
    required this.heroAmountSize,
    required this.heroAmountWeight,
    required this.kpiAmountSize,
    required this.kpiAmountWeight,
    required this.tableAmountSize,
    required this.fontFeatureTabular,
    required this.skeletonBase,
    required this.skeletonShimmer,
    required this.skeletonDuration,
    required this.skeletonRadius,
  });

  factory PremiumThemeExtension.dark() {
    return PremiumThemeExtension(
      canvasDeep: const Color(0xFF07090A),
      canvasMid: const Color(0xFF0E1210),
      glassSurface: const Color(0xFFFFFFFF).withValues(alpha: 0.05),
      glassSurfaceHero: const Color(0xFFFFFFFF).withValues(alpha: 0.08),
      glassBorder: const Color.fromRGBO(255, 255, 255, 0.08),
      glassBorderActive: const Color.fromRGBO(255, 255, 255, 0.18),
      glassBorderAccent: const Color.fromRGBO(104, 158, 40, 0.35),
      glassOverlay: const Color.fromRGBO(255, 255, 255, 0.03),
      glowGreenOpacity: 0.12,
      glowGreenRadius: 40.0,
      glowGreenBlur: 60.0,
      glowDangerOpacity: 0.10,
      glowDangerRadius: 30.0,
      blurSigma: 32.0,
      blurEnabled: true,
      heroCardGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF689E28).withValues(alpha: 0.15),
          const Color(0xFFFFFFFF).withValues(alpha: 0.03),
        ],
      ),
      accentLineGradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF689E28), Colors.transparent],
      ),
      dangerLineGradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFEF4444), Colors.transparent],
      ),
      warmthGradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1A1200), Color(0xFF0E0E0E)],
      ),
      heroAmountSize: 40.0,
      heroAmountWeight: FontWeight.w200,
      kpiAmountSize: 22.0,
      kpiAmountWeight: FontWeight.w600,
      tableAmountSize: 13.0,
      fontFeatureTabular: const [FontFeature.tabularFigures()],
      skeletonBase: const Color.fromRGBO(255, 255, 255, 0.04),
      skeletonShimmer: const Color.fromRGBO(255, 255, 255, 0.10),
      skeletonDuration: const Duration(milliseconds: 1400),
      skeletonRadius: 6.0,
    );
  }

  factory PremiumThemeExtension.light() {
    return PremiumThemeExtension(
      canvasDeep: const Color(0xFFEBEDEA),
      canvasMid: const Color(0xFFE4EBE0),
      glassSurface: Colors.white.withValues(alpha: 0.65),
      glassSurfaceHero: Colors.white.withValues(alpha: 0.85),
      glassBorder: Colors.white.withValues(alpha: 0.90),
      glassBorderActive: const Color(0xFF689E28).withValues(alpha: 0.5),
      glassBorderAccent: const Color(0xFF689E28).withValues(alpha: 0.5),
      glassOverlay: Colors.black.withValues(alpha: 0.04),
      glowGreenOpacity: 0.08,
      glowGreenRadius: 30.0,
      glowGreenBlur: 40.0,
      glowDangerOpacity: 0.05,
      glowDangerRadius: 20.0,
      blurSigma: 32.0,
      blurEnabled: true,
      heroCardGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF689E28).withValues(alpha: 0.12),
          Colors.white.withValues(alpha: 0.75),
        ],
      ),
      accentLineGradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF689E28), Colors.transparent],
      ),
      dangerLineGradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFEF4444), Colors.transparent],
      ),
      warmthGradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFF5F5), Colors.white],
      ),
      heroAmountSize: 40.0,
      heroAmountWeight: FontWeight.w200,
      kpiAmountSize: 22.0,
      kpiAmountWeight: FontWeight.w600,
      tableAmountSize: 13.0,
      fontFeatureTabular: const [FontFeature.tabularFigures()],
      skeletonBase: const Color(0xFFE5E7EB),
      skeletonShimmer: const Color(0xFFF3F4F6),
      skeletonDuration: const Duration(milliseconds: 1400),
      skeletonRadius: 6.0,
    );
  }

  @override
  PremiumThemeExtension copyWith({
    Color? canvasDeep,
    Color? canvasMid,
    Color? glassSurface,
    Color? glassSurfaceHero,
    Color? glassBorder,
    Color? glassBorderActive,
    Color? glassBorderAccent,
    Color? glassOverlay,
    double? glowGreenOpacity,
    double? glowGreenRadius,
    double? glowGreenBlur,
    double? glowDangerOpacity,
    double? glowDangerRadius,
    double? blurSigma,
    bool? blurEnabled,
    Gradient? heroCardGradient,
    Gradient? accentLineGradient,
    Gradient? dangerLineGradient,
    Gradient? warmthGradient,
    double? heroAmountSize,
    FontWeight? heroAmountWeight,
    double? kpiAmountSize,
    FontWeight? kpiAmountWeight,
    double? tableAmountSize,
    List<FontFeature>? fontFeatureTabular,
    Color? skeletonBase,
    Color? skeletonShimmer,
    Duration? skeletonDuration,
    double? skeletonRadius,
  }) {
    return PremiumThemeExtension(
      canvasDeep: canvasDeep ?? this.canvasDeep,
      canvasMid: canvasMid ?? this.canvasMid,
      glassSurface: glassSurface ?? this.glassSurface,
      glassSurfaceHero: glassSurfaceHero ?? this.glassSurfaceHero,
      glassBorder: glassBorder ?? this.glassBorder,
      glassBorderActive: glassBorderActive ?? this.glassBorderActive,
      glassBorderAccent: glassBorderAccent ?? this.glassBorderAccent,
      glassOverlay: glassOverlay ?? this.glassOverlay,
      glowGreenOpacity: glowGreenOpacity ?? this.glowGreenOpacity,
      glowGreenRadius: glowGreenRadius ?? this.glowGreenRadius,
      glowGreenBlur: glowGreenBlur ?? this.glowGreenBlur,
      glowDangerOpacity: glowDangerOpacity ?? this.glowDangerOpacity,
      glowDangerRadius: glowDangerRadius ?? this.glowDangerRadius,
      blurSigma: blurSigma ?? this.blurSigma,
      blurEnabled: blurEnabled ?? this.blurEnabled,
      heroCardGradient: heroCardGradient ?? this.heroCardGradient,
      accentLineGradient: accentLineGradient ?? this.accentLineGradient,
      dangerLineGradient: dangerLineGradient ?? this.dangerLineGradient,
      warmthGradient: warmthGradient ?? this.warmthGradient,
      heroAmountSize: heroAmountSize ?? this.heroAmountSize,
      heroAmountWeight: heroAmountWeight ?? this.heroAmountWeight,
      kpiAmountSize: kpiAmountSize ?? this.kpiAmountSize,
      kpiAmountWeight: kpiAmountWeight ?? this.kpiAmountWeight,
      tableAmountSize: tableAmountSize ?? this.tableAmountSize,
      fontFeatureTabular: fontFeatureTabular ?? this.fontFeatureTabular,
      skeletonBase: skeletonBase ?? this.skeletonBase,
      skeletonShimmer: skeletonShimmer ?? this.skeletonShimmer,
      skeletonDuration: skeletonDuration ?? this.skeletonDuration,
      skeletonRadius: skeletonRadius ?? this.skeletonRadius,
    );
  }

  @override
  PremiumThemeExtension lerp(ThemeExtension<PremiumThemeExtension>? other, double t) {
    if (other is! PremiumThemeExtension) {
      return this;
    }
    return PremiumThemeExtension(
      canvasDeep: Color.lerp(canvasDeep, other.canvasDeep, t) ?? canvasDeep,
      canvasMid: Color.lerp(canvasMid, other.canvasMid, t) ?? canvasMid,
      glassSurface: Color.lerp(glassSurface, other.glassSurface, t) ?? glassSurface,
      glassSurfaceHero: Color.lerp(glassSurfaceHero, other.glassSurfaceHero, t) ?? glassSurfaceHero,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t) ?? glassBorder,
      glassBorderActive: Color.lerp(glassBorderActive, other.glassBorderActive, t) ?? glassBorderActive,
      glassBorderAccent: Color.lerp(glassBorderAccent, other.glassBorderAccent, t) ?? glassBorderAccent,
      glassOverlay: Color.lerp(glassOverlay, other.glassOverlay, t) ?? glassOverlay,
      glowGreenOpacity: lerpDouble(glowGreenOpacity, other.glowGreenOpacity, t) ?? glowGreenOpacity,
      glowGreenRadius: lerpDouble(glowGreenRadius, other.glowGreenRadius, t) ?? glowGreenRadius,
      glowGreenBlur: lerpDouble(glowGreenBlur, other.glowGreenBlur, t) ?? glowGreenBlur,
      glowDangerOpacity: lerpDouble(glowDangerOpacity, other.glowDangerOpacity, t) ?? glowDangerOpacity,
      glowDangerRadius: lerpDouble(glowDangerRadius, other.glowDangerRadius, t) ?? glowDangerRadius,
      blurSigma: lerpDouble(blurSigma, other.blurSigma, t) ?? blurSigma,
      blurEnabled: t < 0.5 ? blurEnabled : other.blurEnabled,
      heroCardGradient: Gradient.lerp(heroCardGradient, other.heroCardGradient, t) ?? heroCardGradient,
      accentLineGradient: Gradient.lerp(accentLineGradient, other.accentLineGradient, t) ?? accentLineGradient,
      dangerLineGradient: Gradient.lerp(dangerLineGradient, other.dangerLineGradient, t) ?? dangerLineGradient,
      warmthGradient: Gradient.lerp(warmthGradient, other.warmthGradient, t) ?? warmthGradient,
      heroAmountSize: lerpDouble(heroAmountSize, other.heroAmountSize, t) ?? heroAmountSize,
      heroAmountWeight: FontWeight.lerp(heroAmountWeight, other.heroAmountWeight, t) ?? heroAmountWeight,
      kpiAmountSize: lerpDouble(kpiAmountSize, other.kpiAmountSize, t) ?? kpiAmountSize,
      kpiAmountWeight: FontWeight.lerp(kpiAmountWeight, other.kpiAmountWeight, t) ?? kpiAmountWeight,
      tableAmountSize: lerpDouble(tableAmountSize, other.tableAmountSize, t) ?? tableAmountSize,
      fontFeatureTabular: t < 0.5 ? fontFeatureTabular : other.fontFeatureTabular,
      skeletonBase: Color.lerp(skeletonBase, other.skeletonBase, t) ?? skeletonBase,
      skeletonShimmer: Color.lerp(skeletonShimmer, other.skeletonShimmer, t) ?? skeletonShimmer,
      skeletonDuration: t < 0.5 ? skeletonDuration : other.skeletonDuration,
      skeletonRadius: lerpDouble(skeletonRadius, other.skeletonRadius, t) ?? skeletonRadius,
    );
  }
}
