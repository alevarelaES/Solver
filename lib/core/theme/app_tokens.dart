import 'package:flutter/material.dart';

// ─── Spacing scale ────────────────────────────────────────────────────────────
class AppSpacing {
  const AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Convenience EdgeInsets
  static const EdgeInsets paddingCard = EdgeInsets.all(lg);
  static const EdgeInsets paddingCardCompact = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: md,
  );
  static const EdgeInsets paddingSection = EdgeInsets.all(lg);
  static const EdgeInsets paddingPage = EdgeInsets.all(xxl);
}

// ─── Sizes ────────────────────────────────────────────────────────────────────
class AppSizes {
  const AppSizes._();
  static const double sidebarWidth = 64;
  static const double headerHeight = 56;
  static const double leftColumnWidth = 340;
  static const double rightSidebarWidth = 260;
  static const double cardMinHeight = 100;
  static const double iconBoxSize = 36;
  static const double iconBoxSizeSm = 32;
  static const double iconSize = 18;
  static const double iconSizeSm = 16;
  static const double dotSize = 8;
  static const double dotSizeSm = 6;
  static const double progressBarHeight = 10;
  static const double chartHeight = 180;
  static const double donutSize = 128;
  static const double donutCutout = 42;
  static const double donutRingWidth = 22;
  static const double bankCardWidth = 240;
  static const double bankCardHeight = 150;
  static const double barWidth = 8;
  static const double barRadius = 4;
}

// ─── Shadows ──────────────────────────────────────────────────────────────────
class AppShadows {
  const AppShadows._();

  static List<BoxShadow> get card => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get cardHover => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get elevated => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> cardGreen(Color primary) => [
    BoxShadow(
      color: primary.withValues(alpha: 0.2),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];
}

// ─── Animation durations ──────────────────────────────────────────────────────
class AppDurations {
  const AppDurations._();
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration stagger = Duration(milliseconds: 80);
}

// ─── Breakpoints ──────────────────────────────────────────────────────────────
class AppBreakpoints {
  const AppBreakpoints._();
  static const double mobile = 600;
  static const double tablet = 768;
  static const double desktop = 1024;
  static const double wide = 1280;
}
